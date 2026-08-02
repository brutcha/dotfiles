# astoria — Dell XPS 13 9300 NixOS thin-client

Sofa/bed/bath companion to a TV-connected Nobara desktop. Sway, Moonlight,
LibreWolf. TV inputs via AV receiver → single-scene Sunshine on the host.

Design rationale (why Lanzaboote, why TPM-sealed cryptswap, why sops-nix over a
private flake, threat model) lives in the author's working notes outside the
repo. In-file: each module's header comment carries the "why" for its own
choices; this file is the operator's runbook.

---

## Rebuild
- Preferred: `cd ~/git/dotfiles && sudo nixos-rebuild switch --flake .#astoria`
- Via /etc/nixos symlink: `sudo nixos-rebuild switch --flake /etc/nixos#astoria`
- From dev machine over LAN: `nixos-rebuild switch --flake .#astoria --target-host brutcha@astoria --use-remote-sudo`

## Update
- Flake inputs: `nix flake update` (from dev machine, review lock diff, commit)
- Firmware: `fwupdmgr refresh && fwupdmgr get-updates && fwupdmgr update`

## Rollback

Two independent rollback mechanisms — use the right one for the failure mode.

**NixOS generation rollback** — for reverting a `nixos-rebuild switch` that broke
something:
- Lanzaboote boot menu at boot → pick a previous generation
- Or from CLI (still-booted system): `sudo nixos-rebuild switch --rollback`

**Snapper rootfs rollback** — for reverting non-`/nix/store` drift (files edited
outside the flake, corrupted state under `/etc`, `/var`, `/home`). Snapshots live
under `/.snapshots/<N>/snapshot` and are created at every boot by `snapper-boot.service`:
```bash
sudo snapper -c root list                           # inspect snapshots + timestamps
sudo snapper -c root diff <N>..<M>                  # peek at what would change
sudo snapper -c root undochange <N>..0 <path>       # restore <path> from snapshot N
sudo snapper -c root rollback <N>                   # nuke current @root, replace with snapshot N — reboots into it
```
`snapper rollback` is destructive to the current @root (it swaps subvolumes); prefer
`undochange` for targeted recovery when only a few files are affected.

Note: Snapper's SUBVOLUME is `/` (targets @root only). `/nix`, `/home`, `/.snapshots`
are separate subvolumes and NOT covered — `/nix/store` is already immutable +
content-addressed; `/home` is user data that Restic backs up.

---

## Secrets (sops)

astoria decrypts `hosts/astoria/secrets/astoria.yaml` at boot using its SSH
host key (converted to age) plus a recovery age key — both listed as
recipients under the `&astoria` / `&brutcha_recovery` anchors in `.sops.yaml`
at the repo root. The secret schema sops-nix expects in that YAML is
declared in `hosts/astoria/secrets.nix`.

Tooling docs: [sops-nix](https://github.com/Mic92/sops-nix) (the NixOS
module wiring `.sops.yaml` → `secrets.nix` → `/run/secrets`),
[sops](https://github.com/getsops/sops) (the encryption CLI), and
[age](https://github.com/FiloSottile/age) (the key format).

---

## Dev-machine secrets (only needed for host-key rotation / disaster recovery)

Generating astoria's secrets from scratch needs, once:
- An SSH host key for astoria, converted to age via `ssh-to-age` — its
  pubkey becomes the `&astoria` recipient in `.sops.yaml`; the private key
  goes to `/etc/ssh/ssh_host_ed25519_key` on the machine (Phase 3 step 3)
  and to the vault (`"astoria SSH host key"`) for recovery.
- A recovery age keypair (`age-keygen`, generated once, ever, reused across
  hosts) → pubkey is the `&brutcha_recovery` anchor; private key → vault
  (`"astoria sops recovery"`). Follow the shred discipline in "Recovery age
  key — helper-device shred discipline" below whenever it leaves the vault.
- Login/cryptswap LUKS passphrases, a restic repo password, and a
  `mkpasswd -m yescrypt` password hash — each in its own vault entry
  (`"astoria login"`, `"astoria cryptswap"`, `"astoria restic repo"`), then
  assembled into `hosts/astoria/secrets/astoria.yaml` matching the schema
  declared in `secrets.nix`, and `sops updatekeys
  hosts/astoria/secrets/astoria.yaml`, commit, push.

Tooling docs: [ssh-to-age](https://github.com/Mic92/ssh-to-age),
[age](https://github.com/FiloSottile/age),
[sops](https://github.com/getsops/sops).

---

## Phase 3 — install

Boot the [nix-community/nixos-images](https://github.com/nix-community/nixos-images)
unstable installer ISO. Grab the IP + root password from its on-screen
QR/JSON, then SSH in as root — everything below runs inside that one
session (no `sudo` needed anywhere in this phase, you're already root),
except the host-key transfer, which is run from the dev machine.

```bash
GITHUB_USER=<your-github-username>
ASTORIA_IP=<astoria-lan-ip>       # from the installer's on-screen/QR/clipboard info
ssh "root@${ASTORIA_IP}"
```

### 1. Clone the flake

```bash
nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- \
  clone "https://github.com/${GITHUB_USER}/dotfiles" /tmp/dotfiles
cd /tmp/dotfiles
```

The minimal ISO's closure is intentionally bare, and flakes aren't enabled
by default on it either — anything else needed mid-install has to be
fetched on-demand the same way:
```bash
nix --extra-experimental-features 'nix-command flakes' run nixpkgs#<pkg> -- ...
```
Packages that come up needing this during install: `sops`, `ssh-to-age`,
`sbctl`, `pciutils` (for `lspci`), `stress-ng`, `s-tui`,
`linuxPackages.turbostat`. `sbctl` also needs `--disable-landlock` when
writing outside its expected paths (e.g. `--export /mnt/var/lib/sbctl/keys`
in step 4 below), since it sandboxes itself with Landlock by default.

### 2. Partition + format

This model defaults to **RAID (Intel RST) mode** in BIOS, which hides the
NVMe drive from normal enumeration (`lspci` shows a `RAID bus controller`
instead of a `Non-Volatile memory controller`; `dmesg` shows `ahci ...:
Found 1 remapped NVMe devices`). Fix before running disko: BIOS → System
Configuration → **SATA Operation: AHCI** (switch from RAID). No config
changes needed once this is set correctly — `nvme` in
`boot.initrd.availableKernelModules` is already sufficient once the drive
enumerates natively.

```bash
nix run '.#disko' \
  --extra-experimental-features 'nix-command flakes' \
  -- --mode destroy,format,mount --flake .#astoria
```

`.#disko` (rather than `github:nix-community/disko`) resolves the disko
binary through the flake's own `packages.x86_64-linux.disko` re-export,
which is pinned via `flake.lock` — no unpinned github ref, no MITM-able
fetch, exact same code as everything else the flake produces.

Prompts, in order:
1. `Type 'yes' to continue, anything else to abort:` — type literally `yes`.
   **Don't paste a passphrase here** (anything except `yes` aborts before
   formatting starts). Skip this prompt with `--yes-wipe-all-disks` if
   re-running non-interactively.
2. **cryptswap** LUKS passphrase (2×) — from vault `"astoria cryptswap"`.
3. **cryptroot** LUKS passphrase (2×) — from vault `"astoria login"`.

### 3. Transfer astoria's SSH host key from dev → installer

From the dev machine (a separate terminal from the root SSH session above),
scp the raw private key over, then move it into place with the right
owner/mode and shred the transient copy:
```bash
scp /tmp/astoria_host_key "root@${ASTORIA_IP}:/tmp/astoria_host_key"
ssh "root@${ASTORIA_IP}" 'mkdir -p /mnt/etc/ssh && \
  install -m 600 -o root -g root /tmp/astoria_host_key /mnt/etc/ssh/ssh_host_ed25519_key && \
  shred -u /tmp/astoria_host_key'
```

Back in the installer session, derive the .pub (strict openssh refuses to
read a 0644 private key without a matching .pub):
```bash
ssh-keygen -y -f /mnt/etc/ssh/ssh_host_ed25519_key | \
  install -m 644 -o root -g root /dev/stdin /mnt/etc/ssh/ssh_host_ed25519_key.pub
```

### 4. Generate sbctl Secure Boot keys

`nixos-install` signs the bootloader via Lanzaboote's installHook using these
keys, so they must exist at `/mnt/var/lib/sbctl` before install.

```bash
nix --extra-experimental-features 'nix-command flakes' run nixpkgs#sbctl -- create-keys --help    # confirm flag names first
mkdir -p /mnt/var/lib/sbctl
nix --extra-experimental-features 'nix-command flakes' run nixpkgs#sbctl -- create-keys --export /mnt/var/lib/sbctl/keys --database-path /mnt/var/lib/sbctl/GUID
```

Gotchas:
- `--database-path` is a **file** path (writes a GUID file at that location),
  not a directory. Passing a directory → EISDIR → no keys ever created.
- Older sbctl uses `--keydir` / `--pki-dir` instead. Check `--help` first.

### 5. Install

```bash
nixos-install --flake /tmp/dotfiles#astoria --no-root-passwd
```

During activation:
- sops decrypts `astoria.yaml` using the host key from step 3. Hashed password
  materializes at `/run/secrets-for-users/…` before user creation, so greetd
  accepts login on first boot.
- Lanzaboote signs bootloader + kernel + initrd with the sbctl keys.
- cryptswap TPM keyslot doesn't exist yet — first boot prompts for the
  disko-set passphrase. TPM enrollment happens in Phase 4c.

### 6. Reboot

cryptroot passphrase → cryptswap passphrase (once, until Phase 4c) → greetd
→ user login → Sway.

---

## Phase 4 — first-boot + Secure Boot + TPM

> **Single-sitting rule**: do 4a → 4b → 4c back-to-back, don't leave astoria
> unattended between install and 4c. Between install (SB off, ESP writable
> by any live USB) and Phase 4b's SB-on moment, an attacker with brief
> physical access could plant an unsigned payload on the ESP. When SB flips
> on, firmware measures that payload into PCR 7 as "trusted state"; Phase 4c
> then seals the TPM against that PCR 7. Post-4c the machine is protected.
> Roughly a 30-minute total sitting.

### 4a. Bring-up checks

Still open as of the last session:

- [ ] **Add the dev-machine ssh pubkey** to
      `users.users.brutcha.openssh.authorizedKeys.keys` (edit
      `hosts/astoria/default.nix` in the just-cloned dir, commit, rebuild)
      — required before first `--target-host` rebuild.
- [ ] Manual first Restic backup:
      `sudo systemctl start restic-backups-webdav.service`; journal shows
      success.
- [ ] Password-vault LibreWolf extension: paste server URL, log in with your
      vault account, unlock with the challenge password on first launch
      (one-time, manual).

### 4b. Enroll Secure Boot keys

Enroll BEFORE turning SB on in BIOS — first SB-enabled boot must verify
Lanzaboote against enrolled keys.

```bash
sudo sbctl status                      # Setup Mode: Enabled, Secure Boot: Disabled
sudo sbctl enroll-keys --microsoft     # --microsoft: append MS certs to KEK+db (option ROMs)
sudo sbctl verify                      # every file: ✓ Signed
```

Reboot → BIOS → enable Secure Boot → save. Boots normally, still prompts for
both cryptroot + cryptswap passphrases (TPM not enrolled yet).

Verify from the running system:
```bash
bootctl status | grep 'Secure Boot'    # enabled
sudo sbctl verify
```

### 4c. Enroll TPM keyslot for cryptswap

```bash
ls /sys/class/tpm/                     # tpm0 should be there
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/nvme0n1p2
```

Prompts for the cryptswap passphrase to authorize the new keyslot. PCRs 0/2/7
= firmware code / extended firmware code / SB state — binds key release to
firmware integrity + SB being on.

Reboot to verify: cryptroot passphrase (always), cryptswap unlocks SILENTLY
via TPM (no prompt).

**Recovery if enrollment failed mid-step** (tpm2-tss error, DA-lockout, PCR
read error): the passphrase keyslot is UNAFFECTED — cryptswap still opens
via passphrase. Clean up with:
```bash
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2     # non-fatal if no slot
```
Then retry the enroll command. If DA-locked:
```bash
sudo tpm2_dictionarylockout --clear-lockout                  # blank owner pw on freshly-cleared TPM
```

Verify keyslots:
```bash
sudo systemd-cryptenroll /dev/nvme0n1p2                      # slot 0 (password) + slot N (tpm2)
```

### 4d. Lockdown check

- [ ] `bootctl status` shows Secure Boot enabled, Setup Mode disabled.
- **BIOS admin password NOT recommended** — would prevent unauthorized
  Setup-Mode re-entry but breaks TLP's Dell charge-threshold writes silently.
  SB + PCR sealing already narrow the physical-access attack: any hostile
  re-enrollment invalidates PCR 7 → cryptswap TPM auto-unlock breaks →
  tamper visible on the next boot.

---

## Restore from backup
- Secrets already materialized on running astoria: `/run/secrets/rclone/webdav.conf`
  + `/run/secrets/restic/repo-password`
- `sudo nix-shell -p restic rclone` — enters an interactive root shell with restic +
  rclone on PATH.
- Inside that shell you are already root; rclone runs with `HOME=/root` and doesn't
  find the sops-materialized config unless `RCLONE_CONFIG` is explicit. Same for
  restic's password file. **Do NOT wrap these calls in another `sudo`** — inner sudo
  triggers `env_reset` + PAM PATH reset, which drops the nix-shell's ephemeral PATH.
  Use plain `env`:
  ```bash
  env \
    RCLONE_CONFIG=/run/secrets/rclone/webdav.conf \
    RESTIC_PASSWORD_FILE=/run/secrets/restic/repo-password \
    restic -r rclone:webdav:restic-astoria snapshots
  env \
    RCLONE_CONFIG=/run/secrets/rclone/webdav.conf \
    RESTIC_PASSWORD_FILE=/run/secrets/restic/repo-password \
    restic -r rclone:webdav:restic-astoria restore latest --target /
  ```

## Password recovery (lost sudo password — machine still boots)
1. From a machine that has the recovery age key: `sops hosts/astoria/secrets/astoria.yaml`
   — replace `users.brutcha.hashed-password` with a new `mkpasswd -m yescrypt` hash.
   Commit + push.
2. On astoria: `sudo nixos-rebuild switch` (or `--target-host` from dev machine if
   stuck at greetd).

## Password recovery (fully bricked — installer rescue)
1. Boot NixOS installer USB.
2. `sudo cryptsetup luksOpen /dev/nvme0n1p3 cryptroot`   # p3 = root; p2 = swap
3. `sudo mount -o subvol=@root /dev/mapper/cryptroot /mnt`
4. `sudo mount -o subvol=@nix /dev/mapper/cryptroot /mnt/nix`
5. `sudo mount -o subvol=@home /dev/mapper/cryptroot /mnt/home`
6. `sudo mount /dev/nvme0n1p1 /mnt/boot`
7. `sudo nixos-enter --root /mnt`
8. Do NOT `passwd brutcha` — `users.mutableUsers = false;` reverts it. Update sops
   YAML from a trusted machine and rebuild.

## Recovery age key — helper-device shred discipline

The recovery age private key lives in your password vault. Any time you paste it out
of the vault onto a helper device to run `sops`, follow this discipline:

1. On the helper device, mount a scratch tmpfs first:
   - Linux: `SCRATCH=$(mktemp -d --tmpdir=/dev/shm astoria-recovery.XXXXX)`
   - macOS: plain `~/.config/sops/age/keys.txt` lands on the boot APFS volume where
     `rm` releases the inode but blocks remain until reclaimed, and Time Machine
     local snapshots capture the file for ~24h. Use a RAM disk:
     `hdiutil attach -nomount ram://8192 | xargs -I{} diskutil erasevolume APFS 'ARamDisk' {}; SCRATCH=/Volumes/ARamDisk`
2. Set the cleanup trap FIRST (before any paste):
   ```bash
   trap 'shred -u -- "$SCRATCH"/keys.txt 2>/dev/null; rm -rf "$SCRATCH" 2>/dev/null; diskutil eject ARamDisk 2>/dev/null' EXIT INT TERM
   ```
3. Paste the recovery age private key to `"$SCRATCH"/keys.txt`; `chmod 600 "$SCRATCH"/keys.txt` immediately.
4. `SOPS_AGE_KEY_FILE="$SCRATCH"/keys.txt sops hosts/astoria/secrets/astoria.yaml`
   — decrypt, edit, save, then `sops updatekeys …` to re-encrypt.
5. Commit + push. Exit the shell — the trap fires and shreds the temp key.
6. Verify: `ls -la "$SCRATCH"` should show "No such file". On macOS also verify
   `tmutil listlocalsnapshots /` doesn't show a recent snapshot containing the file
   (they roll off in ~24h; force-delete with `tmutil deletelocalsnapshots`).

## LUKS passphrase change
```bash
sudo cryptsetup luksChangeKey /dev/nvme0n1p3   # cryptroot — also update `"astoria login"` in the vault
sudo cryptsetup luksChangeKey /dev/nvme0n1p2   # cryptswap fallback — also update its vault entry
```
The cryptswap TPM keyslot is separate from the passphrase keyslot; changing the
passphrase does NOT invalidate the TPM binding. Rotate TPM enrollment only if you
need to (BIOS updates, PCR changes).

## TPM re-enrollment (after BIOS/firmware update — expected ~1-2× per year)

Symptoms: first boot after a BIOS update prompts for the cryptswap passphrase
(fallback path) instead of TPM auto-unlock. `journalctl -b -u 'systemd-cryptsetup@luks\x2dswap.service'`
reports PCR mismatch.

Fix:
```bash
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/nvme0n1p2
```
Prompted for the cryptswap passphrase to authorize. Reboot to verify silent unlock.

## Secure Boot state audit (occasional)
```bash
sudo sbctl status              # Setup Mode: Disabled, Secure Boot: Enabled
sudo sbctl verify              # every EFI file: Signed
bootctl status | grep 'Secure'
```
If `sbctl verify` shows unsigned files after a manual bootloader tweak:
`sudo sbctl sign -s <path>` per file, then `sudo nixos-rebuild switch`.

## Full Secure Boot reset (rare — if keys get corrupted or you need to re-provision)

1. Reboot into BIOS. Advanced Boot Options → Secure Boot → "Reset to Setup Mode" (or
   "Delete All Keys").
2. Boot back into NixOS. `sudo sbctl reset` — resets the UEFI PK/KEK/db variables to
   Setup Mode by enrolling an empty signature DB. **`sbctl reset` does NOT touch
   `/var/lib/sbctl`** — the local keypair on disk survives.
3. **Delete the local keypair** so step 4 doesn't silently no-op:
   ```bash
   sudo rm -rf /var/lib/sbctl/keys /var/lib/sbctl/GUID
   ```
   `sbctl create-keys` refuses to overwrite an existing keydir; skipping this rm
   leaves the old keypair in place and the "reset" achieves nothing.
4. `sudo sbctl create-keys` — new keypair, now that the keydir is empty.
5. `sudo nixos-rebuild switch` — re-signs the bootloader + kernel + initrd with the
   new keys.
6. `sudo sbctl enroll-keys --microsoft` — enroll into UEFI.
7. Reboot into BIOS → enable Secure Boot.
8. **TPM state also invalidates** (PCR 7 changes): follow "TPM re-enrollment" above.

## Battery care
Charge thresholds 60/80 via TLP. Check with `tlp-stat -b`. Battery replacement
(~€60, iFixit rating 4/10) recommended if capacity drops below 60 %.

## Known gotchas
- iwlwifi power_save must stay off — turning it on drops Moonlight streams.
- `enhanced-h264ify` blocks AV1 on YouTube while leaving VP9 available; keeps
  4K/1440p playback that plain `h264ify` would silently drop.
- The inlined disko block at the bottom of `hardware.nix` owns the disk layout —
  do NOT re-run `nixos-generate-config`.
- `users.mutableUsers = false;` — never fix passwords with `passwd`; always go
  through sops.
- **DRM sites (Netflix / Prime / Disney+) don't work on astoria** — LibreWolf ships
  Widevine disabled (default-off, user-toggleable). Netflix on Linux additionally
  caps at ~720p. Watch DRM content from the Nobara desktop via Moonlight instead.
- The password-vault LibreWolf extension is declaratively installed but not
  configured — set server URL, log in with your vault account, unlock with the
  challenge password on first launch (manual, one-time).
- **If suspend-then-hibernate fails to wake at the scheduled time**: ADD
  `rtc_cmos.use_acpi_alarm=1` to `boot.kernelParams`. Kernel auto-quirks the ACPI
  SCI alarm path deterministically on Intel + BIOS≥2015 + HPET-on (XPS 13 9300 hits
  all three), so the param is normally redundant and hardware.nix omits it. Kept as
  a documented fallback in case a future BIOS revision breaks the auto-quirk.
- **Cryptswap prompts for a passphrase after a BIOS update**: expected — TPM PCRs
  changed, sd-cryptsetup fell back to the passphrase keyslot. Re-run TPM enrollment
  (see "TPM re-enrollment"). One-time-per-BIOS-bump friction.
- **`sbctl verify` shows unsigned files**: something touched the ESP outside
  `nixos-rebuild switch`. `sudo sbctl sign -s <path>` and rebuild; check the ESP
  wasn't manually edited.
- **Dell Expert Key Management: "Reset All Keys" vs "Delete All Keys"** — these
  are two similarly-labeled, opposite actions. **Reset All Keys** restores
  factory Microsoft/OEM keys (NOT what you want here). **Delete All Keys**
  clears everything and enters Setup Mode (correct). Also: the page's "N
  changes were made" counter does NOT track Delete All Keys — it's an
  immediate action, not a queued setting. Trust `sbctl status` after
  rebooting, not the counter. Also: enabling Secure Boot while the firmware
  has no PK enrolled (Setup Mode + SB on simultaneously) can produce a "no
  bootable devices" SupportAssist screen on some BIOS revisions — leave SB
  off through key deletion + enrollment, and only re-enable it last, once
  `sbctl enroll-keys` has succeeded.

## References

- [NixOS](https://nixos.org)
- [home-manager](https://github.com/nix-community/home-manager)
- [sops-nix](https://github.com/Mic92/sops-nix)
- [disko](https://github.com/nix-community/disko)
- [lanzaboote](https://github.com/nix-community/lanzaboote)
- [snapper](https://github.com/openSUSE/snapper)
- [TLP](https://linrunner.de/tlp/)
- [sbctl](https://github.com/Foxboron/sbctl)
- [nix-community/nixos-images](https://github.com/nix-community/nixos-images)
- [Moonlight](https://moonlight-stream.org)
- [LibreWolf](https://librewolf.net)
