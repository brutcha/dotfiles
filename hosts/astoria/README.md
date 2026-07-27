# astoria — Dell XPS 13 9300 NixOS thin-client

Sofa/bed/bath companion to a TV-connected Nobara desktop. Sway, Moonlight,
LibreWolf. TV inputs via AV receiver → single-scene Sunshine on the host.

Design rationale (why Lanzaboote, why TPM-sealed cryptswap, why sops-nix over a
private flake, threat model) lives in the author's working notes outside the
repo. In-file: each module's header comment carries the "why" for its own
choices; this file is the operator's runbook.

---

## Prerequisites (one-time, before touching astoria)

- [ ] **Password vault** reachable from a non-astoria device. astoria decrypts
      its own secrets on first boot using its host SSH key — if that key ever
      dies, recovery needs the age key stored in the vault. No non-astoria
      vault access = no recovery.
- [ ] **Vault end-to-end / client-side encryption enabled** — set the vault's
      unlock secret. Without it, the server operator can read every entry.
      Verify the setting is active before storing recovery material.
- [ ] **WebDAV app-password** for astoria, from your WebDAV backend's web UI
      (Devices/Sessions/Tokens section, label `"astoria-restic"`). DO NOT
      reuse the main account password.
- [ ] **rclone-obscure the app-password** for use in rclone.conf (Phase 1
      step 7):
      ```
      nix-shell -p rclone --run 'rclone obscure APP_PASSWORD'
      ```
- [ ] **WebDAV endpoint sanity check** — auth works, directory lists.
      `-u USER` (no colon) makes curl prompt for the password on tty rather
      than leaving it in argv / scrollback / `ps`:
      ```
      curl -X PROPFIND -H 'Depth: 0' -u USER https://WEBDAV_HOST/WEBDAV_ROOT/
      ```
      Success = `<d:multistatus>…</d:multistatus>` XML.

> **First install vs reinstall**: on the very first install, Phase 0 + Phase 1
> were already done during scaffolding — skip to Phase 2. Phases 0/1 below are
> the runbook for reinstalls (host key rotation, HW replacement, disaster
> recovery).

---

## Phase 0 — repo scaffolding (one-time)

Create `.sops.yaml` at the repo root with placeholder recipients (Phase 1 step
1+2 fills in the real pubkeys). Commit + push.

---

## Phase 1 — pre-generate on the dev machine

Dev machine = any host you already trust with the repo checked out.

**Placeholder convention** — anywhere you see `<foo>` below, substitute BEFORE
running. Bash treats `<` as an input-redirect metachar, so pasting `<foo>` as
part of a command silently misbehaves rather than erroring.

**Cleanup discipline** — Phase 1 writes plaintext secrets to `/tmp` and shreds
them at exit. On macOS `/tmp` is APFS (persistent, `shred` unreliable); on
Linux usually tmpfs. A bash `trap` on EXIT/INT/TERM shreds on any clean exit.
The trap must be set INSIDE the nix-shell subshell — traps don't propagate
across exec into a fresh bash. For maximum hygiene, do Phase 1 in `/dev/shm`
(Linux) or an hdiutil RAM disk (macOS).

### Enter the shell

```bash
cd ~/git/dotfiles
nix-shell -p ssh-to-age age sops mkpasswd
```

Wait for the `[nix-shell:…]$` prompt, then paste FIRST:

```bash
trap 'shred -u -- /tmp/astoria_host_key* /tmp/recovery.txt /tmp/astoria-hash 2>/dev/null || rm -Pf -- /tmp/astoria_host_key* /tmp/recovery.txt /tmp/astoria-hash 2>/dev/null' EXIT INT TERM
```

### Steps

1. **Astoria host SSH key**
   ```
   ssh-keygen -t ed25519 -f /tmp/astoria_host_key -N '' -C mail@brutcha.dev
   ssh-to-age -i /tmp/astoria_host_key.pub
   ```
   - Pubkey line → replace `age1astoriahostPUBKEY_TBD` in `.sops.yaml`.
   - Private key → vault entry `"astoria SSH host key"`. If your vault's
     Password field rejects multi-line PEM, base64 it to a single line first
     (decoded back during Phase 3 step 4):
     ```
     base64 -i /tmp/astoria_host_key | tr -d '\n' | pbcopy          # macOS
     base64    /tmp/astoria_host_key | tr -d '\n' | xclip -sel c    # Linux (X11)
     base64    /tmp/astoria_host_key | tr -d '\n' | wl-copy         # Linux (Wayland)
     ```

2. **Recovery age keypair** (once, ever)
   ```
   age-keygen -o /tmp/recovery.txt
   ```
   - Pubkey → replace `age1recoveryPUBKEY_TBD` in `.sops.yaml`.
   - `AGE-SECRET-KEY-1…` line → vault entry `"astoria sops recovery"`
     (single-line, no base64 needed).

3. **Export recovery key for sops**
   ```
   export SOPS_AGE_KEY_FILE=/tmp/recovery.txt
   ```
   Step 7 encrypts fresh (only needs pubkeys). Step 8 (`sops updatekeys`)
   decrypts + re-encrypts and needs the recovery key.

4. **Login passphrase** → vault entry `"astoria login"`. Used for cryptroot
   LUKS AND user login (same value; muscle memory). English-keyboard
   typeable — the LUKS prompt uses US layout.

4a. **Cryptswap fallback passphrase** → vault entry `"astoria cryptswap"`.
    Different value from `"astoria login"`. Only ever typed when TPM
    auto-unlock fails (BIOS updates, TPM state changes).

5. **Restic repo password** → vault entry `"astoria restic repo"`. Strong
   random:
   ```
   openssl rand -base64 48
   ```

6. **User password hash** — via temp file to keep the hash off scrollback:
   ```
   mkpasswd -m yescrypt > /tmp/astoria-hash
   ```
   Enter the login passphrase from step 4 at the prompt.

7. **Populate secrets YAML**
   ```
   mkdir -p hosts/astoria/secrets     # sops uses os.WriteFile — no MkdirAll
   sops hosts/astoria/secrets/astoria.yaml
   ```
   Top-level YAML keys must match what sops-nix looks up (see `secrets.nix`):
   ```yaml
   users:
     brutcha:
       hashed-password: PASTE_FROM_/tmp/astoria-hash
   restic:
     repo-password: PASTE_FROM_STEP_5
   rclone:
     webdav.conf: |
       [webdav]
       type = webdav
       url = https://WEBDAV_HOST/WEBDAV_ROOT
       vendor = RCLONE_WEBDAV_VENDOR
       user = WEBDAV_USER
       pass = OBSCURED_FROM_PREREQUISITES
   ```
   If ANY placeholder remains angle-bracketed on save,
   `restic-backups-webdav.service` will fail on first boot.

8. **Encrypt to both recipients**
   ```
   sops updatekeys hosts/astoria/secrets/astoria.yaml
   ```

9. **Commit + push**.

10. **Shred + clear scrollback**
    ```
    shred -u /tmp/astoria_host_key* /tmp/recovery.txt /tmp/astoria-hash
    printf '\033c'
    ```

---

## Phase 2 — physical machine prep

### BIOS

- [ ] **Flash latest firmware first** — Windows Dell Update or `fwupdmgr update`
      from the installer. Doing this AFTER Phase 4c TPM enrollment invalidates
      PCR seals (avoidable round trip).
- [ ] **Signs of Life off**.
- [ ] **BIOS admin password UNSET** (TLP charge thresholds require it).
- [ ] **Secure Boot: OFF, in Setup Mode** — Advanced Boot Options → Secure
      Boot → "Reset to Setup Mode" / "Delete All Keys". Some Dell BIOSes
      need an admin password to reach this menu: set → reset SB → unset.
- [ ] **TPM: On, and cleared** — Security → TPM → Clear TPM.

### Installer

- [ ] **Boot NixOS 26.11 minimal installer USB** (nixos-unstable ISO OK
      while 26.11 is pre-release — flake pins nixpkgs to the same channel).
- [ ] **Wi-Fi**:
      ```
      nmcli device wifi connect <ssid> password <psk>
      ```

---

## Phase 3 — install

```
GITHUB_USER=<your-github-username>
ASTORIA_IP=<astoria-lan-ip>       # from `ip addr | grep 'inet '` on the installer
```

### 1. Clone the flake

```
nix-shell -p git
git clone "https://github.com/${GITHUB_USER}/dotfiles" /tmp/dotfiles
cd /tmp/dotfiles
```

### 2. Hardware inventory

Run the verify script from the just-cloned (git-verified) copy — never
pipe a raw HTTP response into `sh`; a compromised repo tag or an MITM'd
CDN response would execute unreviewed. `hardware.nix` assumes AX201 /
Ice Lake; adjust it if the output disagrees BEFORE the install step.

```
sh hosts/astoria/verify-hardware.sh
```

If it flags a QCA6390 Wi-Fi chip, unavailable `platform_profile`,
non-`s2idle` sleep mode, etc., edit `hosts/astoria/hardware.nix` now
(see the in-file comments for the alternate values) — the install
step below picks up the changes.

### 3. Partition + format

```
sudo nix run 'github:nix-community/disko' \
  --extra-experimental-features 'nix-command flakes' \
  -- --mode destroy,format,mount --flake .#astoria
```

Why the flags: `sudo` because disko doesn't self-elevate; the
`--extra-experimental-features` inline because NixOS sudo drops `NIX_CONFIG`
env, so `export NIX_CONFIG=…` in the outer shell wouldn't survive.

Prompts, in order:
1. `Type 'yes' to continue, anything else to abort:` — type literally `yes`.
   **Don't paste a passphrase here** (anything except `yes` aborts before
   formatting starts). Skip this prompt with `--yes-wipe-all-disks` if
   re-running non-interactively.
2. **cryptswap** LUKS passphrase (2×) — from vault `"astoria cryptswap"`.
3. **cryptroot** LUKS passphrase (2×) — from vault `"astoria login"`.

### 4. Transfer astoria's SSH host key from dev → installer

On the installer, set a throwaway login password (the `nixos` user starts
empty, which blocks ssh):
```
sudo passwd nixos
```

On the dev machine, pipe the base64'd key from clipboard through `base64 -d`
into the installer over ssh. `sudo install` (below) atomically creates the
target file with the right owner + 0600 mode — no umask window during which
the file would be world-readable.

```
# Option A — Linux dev (xclip):
xclip -o -selection clipboard | base64 -d | ssh "nixos@${ASTORIA_IP}" \
  'sudo mkdir -p /mnt/etc/ssh && sudo install -m 600 -o root -g root /dev/stdin /mnt/etc/ssh/ssh_host_ed25519_key'

# Option B — macOS dev (pbpaste):
pbpaste | base64 -d | ssh "nixos@${ASTORIA_IP}" \
  'sudo mkdir -p /mnt/etc/ssh && sudo install -m 600 -o root -g root /dev/stdin /mnt/etc/ssh/ssh_host_ed25519_key'

# Option C — heredoc paste (no clipboard tool available):
ssh "nixos@${ASTORIA_IP}" 'sudo mkdir -p /mnt/etc/ssh && base64 -d | sudo install -m 600 -o root -g root /dev/stdin /mnt/etc/ssh/ssh_host_ed25519_key' <<'EOF'
<paste-base64-string-from-vault-here>
EOF
```

If you stored the key as raw PEM (not base64), drop the `| base64 -d` and
paste the PEM directly.

On the installer, derive the .pub (strict openssh refuses to read a 0644
private key without a matching .pub):
```
sudo ssh-keygen -y -f /mnt/etc/ssh/ssh_host_ed25519_key | \
  sudo install -m 644 -o root -g root /dev/stdin /mnt/etc/ssh/ssh_host_ed25519_key.pub
```

### 5. Generate sbctl Secure Boot keys

`nixos-install` signs the bootloader via Lanzaboote's installHook using these
keys, so they must exist at `/mnt/var/lib/sbctl` before install.

```
sudo nix-shell -p sbctl --run 'sbctl create-keys --help'    # confirm flag names first
sudo mkdir -p /mnt/var/lib/sbctl
sudo nix-shell -p sbctl --run 'sbctl create-keys --export /mnt/var/lib/sbctl/keys --database-path /mnt/var/lib/sbctl/GUID'
```

Gotchas:
- `--database-path` is a **file** path (writes a GUID file at that location),
  not a directory. Passing a directory → EISDIR → no keys ever created.
- Older sbctl uses `--keydir` / `--pki-dir` instead. Check `--help` first.

### 6. Install

```
sudo nixos-install --flake /tmp/dotfiles#astoria --no-root-passwd
```

During activation:
- sops decrypts `astoria.yaml` using the host key from step 3. Hashed password
  materializes at `/run/secrets-for-users/…` before user creation, so greetd
  accepts login on first boot.
- Lanzaboote signs bootloader + kernel + initrd with the sbctl keys.
- cryptswap TPM keyslot doesn't exist yet — first boot prompts for the
  disko-set passphrase. TPM enrollment happens in Phase 4c.

### 7. Reboot

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

- [ ] Cryptroot + cryptswap passphrases accept vault values.
- [ ] Sway starts (`Mod4+Return` → ghostty; `Mod4+Space` → fuzzel; Capslock
      cycles us↔cz).
- [ ] `systemctl status sops-install-secrets` — active, exit 0.
- [ ] `ls /run/secrets-for-users/users/brutcha/` — hashed-password present.
- [ ] `ls /run/secrets/{restic,rclone}/` — secrets present.
- [ ] `lspci -k` — Wi-Fi chip matches Phase 3 hw-inventory output.
- [ ] `cat /sys/power/mem_sleep` — `[s2idle]` bracketed.
- [ ] **Git-clone the flake** to `/home/brutcha/git/dotfiles` — otherwise
      `environment.etc.nixos.source` is a dangling symlink and later
      edit-then-rebuild has no on-machine flake to edit.
- [ ] **Add the dev-machine ssh pubkey** to
      `users.users.brutcha.openssh.authorizedKeys.keys` (edit
      `hosts/astoria/default.nix` in the just-cloned dir, commit, rebuild)
      — required before first `--target-host` rebuild.
- [ ] Manual first Restic backup:
      `sudo systemctl start restic-backups-webdav.service`; journal shows
      success.
- [ ] LibreWolf `about:support` → `HARDWARE_VIDEO_DECODING = available`.
- [ ] Password-vault LibreWolf extension: paste server URL, log in with your
      vault account, unlock with the challenge password on first launch
      (one-time, manual).

### 4b. Enroll Secure Boot keys

Enroll BEFORE turning SB on in BIOS — first SB-enabled boot must verify
Lanzaboote against enrolled keys.

```
sudo sbctl status                      # Setup Mode: Enabled, Secure Boot: Disabled
sudo sbctl enroll-keys --microsoft     # --microsoft: append MS certs to KEK+db (option ROMs)
sudo sbctl verify                      # every file: ✓ Signed
```

Reboot → BIOS → enable Secure Boot → save. Boots normally, still prompts for
both cryptroot + cryptswap passphrases (TPM not enrolled yet).

Verify from the running system:
```
bootctl status | grep 'Secure Boot'    # enabled
sudo sbctl verify
```

### 4c. Enroll TPM keyslot for cryptswap

```
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
```
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2     # non-fatal if no slot
```
Then retry the enroll command. If DA-locked:
```
sudo tpm2_dictionarylockout --clear-lockout                  # blank owner pw on freshly-cleared TPM
```

Verify keyslots:
```
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

## Operations reference (keep post-install)

### Rebuild
- Preferred: `cd ~/git/dotfiles && sudo nixos-rebuild switch --flake .#astoria`
- Via /etc/nixos symlink: `sudo nixos-rebuild switch --flake /etc/nixos#astoria`
- From dev machine over LAN: `nixos-rebuild switch --flake .#astoria --target-host brutcha@astoria --use-remote-sudo`

### Update
- Flake inputs: `nix flake update` (from dev machine, review lock diff, commit)
- Firmware: `fwupdmgr refresh && fwupdmgr get-updates && fwupdmgr update`

### Rollback

Two independent rollback mechanisms — use the right one for the failure mode.

**NixOS generation rollback** — for reverting a `nixos-rebuild switch` that broke
something:
- Lanzaboote boot menu at boot → pick a previous generation
- Or from CLI (still-booted system): `sudo nixos-rebuild switch --rollback`

**Snapper rootfs rollback** — for reverting non-`/nix/store` drift (files edited
outside the flake, corrupted state under `/etc`, `/var`, `/home`). Snapshots live
under `/.snapshots/<N>/snapshot` and are created at every boot by `snapper-boot.service`:
```
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

### Restore from backup
- Secrets already materialized on running astoria: `/run/secrets/rclone/webdav.conf`
  + `/run/secrets/restic/repo-password`
- `sudo nix-shell -p restic rclone` — enters an interactive root shell with restic +
  rclone on PATH.
- Inside that shell you are already root; rclone runs with `HOME=/root` and doesn't
  find the sops-materialized config unless `RCLONE_CONFIG` is explicit. Same for
  restic's password file. **Do NOT wrap these calls in another `sudo`** — inner sudo
  triggers `env_reset` + PAM PATH reset, which drops the nix-shell's ephemeral PATH.
  Use plain `env`:
  ```
  env \
    RCLONE_CONFIG=/run/secrets/rclone/webdav.conf \
    RESTIC_PASSWORD_FILE=/run/secrets/restic/repo-password \
    restic -r rclone:webdav:restic-astoria snapshots
  env \
    RCLONE_CONFIG=/run/secrets/rclone/webdav.conf \
    RESTIC_PASSWORD_FILE=/run/secrets/restic/repo-password \
    restic -r rclone:webdav:restic-astoria restore latest --target /
  ```

### Password recovery (lost sudo password — machine still boots)
1. From a machine that has the recovery age key: `sops hosts/astoria/secrets/astoria.yaml`
   — replace `users.brutcha.hashed-password` with a new `mkpasswd -m yescrypt` hash.
   Commit + push.
2. On astoria: `sudo nixos-rebuild switch` (or `--target-host` from dev machine if
   stuck at greetd).

### Password recovery (fully bricked — installer rescue)
1. Boot NixOS installer USB.
2. `sudo cryptsetup luksOpen /dev/nvme0n1p3 cryptroot`   # p3 = root; p2 = swap
3. `sudo mount -o subvol=@root /dev/mapper/cryptroot /mnt`
4. `sudo mount -o subvol=@nix /dev/mapper/cryptroot /mnt/nix`
5. `sudo mount -o subvol=@home /dev/mapper/cryptroot /mnt/home`
6. `sudo mount /dev/nvme0n1p1 /mnt/boot`
7. `sudo nixos-enter --root /mnt`
8. Do NOT `passwd brutcha` — `users.mutableUsers = false;` reverts it. Update sops
   YAML from a trusted machine and rebuild.

### Recovery age key — helper-device shred discipline

The recovery age private key lives in your password vault. Any time you paste it out
of the vault onto a helper device to run `sops`, mirror Phase 1's shred discipline:

1. On the helper device, mount a scratch tmpfs first:
   - Linux: `SCRATCH=$(mktemp -d --tmpdir=/dev/shm astoria-recovery.XXXXX)`
   - macOS: plain `~/.config/sops/age/keys.txt` lands on the boot APFS volume where
     `rm` releases the inode but blocks remain until reclaimed, and Time Machine
     local snapshots capture the file for ~24h. Use a RAM disk:
     `hdiutil attach -nomount ram://8192 | xargs -I{} diskutil erasevolume APFS 'ARamDisk' {}; SCRATCH=/Volumes/ARamDisk`
2. Set the cleanup trap FIRST (before any paste):
   ```
   trap 'shred -u -- "$SCRATCH"/keys.txt 2>/dev/null; rm -rf "$SCRATCH" 2>/dev/null; diskutil eject ARamDisk 2>/dev/null' EXIT INT TERM
   ```
3. Paste the recovery age private key to `"$SCRATCH"/keys.txt`; `chmod 600 "$SCRATCH"/keys.txt` immediately.
4. `SOPS_AGE_KEY_FILE="$SCRATCH"/keys.txt sops hosts/astoria/secrets/astoria.yaml`
   — decrypt, edit, save, then `sops updatekeys …` to re-encrypt.
5. Commit + push. Exit the shell — the trap fires and shreds the temp key.
6. Verify: `ls -la "$SCRATCH"` should show "No such file". On macOS also verify
   `tmutil listlocalsnapshots /` doesn't show a recent snapshot containing the file
   (they roll off in ~24h; force-delete with `tmutil deletelocalsnapshots`).

### LUKS passphrase change
```
sudo cryptsetup luksChangeKey /dev/nvme0n1p3   # cryptroot — also update `"astoria login"` in the vault
sudo cryptsetup luksChangeKey /dev/nvme0n1p2   # cryptswap fallback — also update its vault entry
```
The cryptswap TPM keyslot is separate from the passphrase keyslot; changing the
passphrase does NOT invalidate the TPM binding. Rotate TPM enrollment only if you
need to (BIOS updates, PCR changes).

### TPM re-enrollment (after BIOS/firmware update — expected ~1-2× per year)

Symptoms: first boot after a BIOS update prompts for the cryptswap passphrase
(fallback path) instead of TPM auto-unlock. `journalctl -b -u 'systemd-cryptsetup@luks\x2dswap.service'`
reports PCR mismatch.

Fix:
```
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/nvme0n1p2
```
Prompted for the cryptswap passphrase to authorize. Reboot to verify silent unlock.

### Secure Boot state audit (occasional)
```
sudo sbctl status              # Setup Mode: Disabled, Secure Boot: Enabled
sudo sbctl verify              # every EFI file: Signed
bootctl status | grep 'Secure'
```
If `sbctl verify` shows unsigned files after a manual bootloader tweak:
`sudo sbctl sign -s <path>` per file, then `sudo nixos-rebuild switch`.

### Full Secure Boot reset (rare — if keys get corrupted or you need to re-provision)

1. Reboot into BIOS. Advanced Boot Options → Secure Boot → "Reset to Setup Mode" (or
   "Delete All Keys").
2. Boot back into NixOS. `sudo sbctl reset` — resets the UEFI PK/KEK/db variables to
   Setup Mode by enrolling an empty signature DB. **`sbctl reset` does NOT touch
   `/var/lib/sbctl`** — the local keypair on disk survives.
3. **Delete the local keypair** so step 4 doesn't silently no-op:
   ```
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

### Battery care
Charge thresholds 60/80 via TLP. Check with `tlp-stat -b`. Battery replacement
(~€60, iFixit rating 4/10) recommended if capacity drops below 60 %.

### Known gotchas
- Wi-Fi tuning assumes AX201 — see `hardware.nix` comments for QCA6390 variant.
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
- `PLATFORM_PROFILE_ON_BAT` in TLP may be a silent no-op if
  `/sys/firmware/acpi/platform_profile_choices` is empty on this SKU —
  verify-hardware.sh reports this; TLP tolerates.
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
- **Cannot enter Secure Boot Setup Mode from BIOS**: some Dell BIOSes require an
  admin password to be set before Setup Mode is reachable. Set one first if BIOS
  refuses; reset SB to Setup Mode; then UNSET the admin password (TLP charge
  thresholds require it UNSET).
