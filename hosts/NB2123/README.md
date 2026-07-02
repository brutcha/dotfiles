# NB2123 (work MacBook)

macOS, aarch64-darwin. Corporate gateway for Claude Code, Azure DevOps package registry, and a corp CA bundle.

## Rebuild

```bash
nix flake update
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#NB2123 --impure
```

`--impure` is required because the flake reads `~/.config/dotfiles/private.nix` — see [First-time setup](#first-time-setup).

Plain `darwin-rebuild` from PATH does not resolve on this machine; use the `nix run` form.

Build without activating:

```bash
sudo nix run nix-darwin/master#darwin-rebuild -- build --flake .#NB2123 --impure
```

## First-time setup

Corp secrets are extracted from a KeePassXC vault at activation time, unlocked by a master password cached in macOS Keychain. No secrets ever enter `/nix/store`.

### 1. Populate the KDBX vault

Symlink the corp KDBX at `~/.config/dotfiles/vault.kdbx` (typical: OneDrive-synced master DB). Populate a `corp/` group with:

| Entry path | Field | Content |
|---|---|---|
| `corp/anthropic-jwt` | Password | Corp Anthropic-gateway JWT |
| `corp/anthropic-base-url` | Password | Gateway URL (e.g. `https://proxy.corp/v1/claude`) |
| `corp/azure-devops-pat` | Password | Azure DevOps Artifacts PAT |
| `corp/ca-bundle` | Attachment `ca.pem` | Corp internal CA in PEM format |

```bash
DB=~/.config/dotfiles/vault.kdbx
keepassxc-cli mkdir "$DB" corp
keepassxc-cli add -p "$DB" corp/anthropic-jwt
keepassxc-cli add -p "$DB" corp/anthropic-base-url
keepassxc-cli add -p "$DB" corp/azure-devops-pat
keepassxc-cli add "$DB" corp/ca-bundle
keepassxc-cli attachment-import "$DB" corp/ca-bundle ca.pem /path/to/corp-ca.pem
```

### 2. Cache the KDBX master password in Keychain

```bash
security add-generic-password -a du234 -s kdbx-master -w '<KDBX master password>' -A
```

`-A` allows any application to read without prompting on first access. Omit if you want the Keychain access dialog per app.

### 3. Create `private.nix` (non-secret host metadata)

```bash
mkdir -p ~/.config/dotfiles && chmod 0700 ~/.config/dotfiles
cp hosts/NB2123/private.example.nix ~/.config/dotfiles/private.nix
chmod 0600 ~/.config/dotfiles/private.nix
$EDITOR ~/.config/dotfiles/private.nix   # user identity + npa org names
```

Expected fields: `user.{name,email}`, `npa.{projectId,adoOrganization,registryFeed,registryScope}`. **No `secrets` attribute** — that's all in the vault now.

### 4. Rebuild

Two activations do the work:

- `cert-bundle.nix` (system) — extracts `corp/ca-bundle` via `launchctl asuser + sudo -u du234 keepassxc-cli`, merges with `/etc/ssl/cert.pem` into `/etc/nix/cert-bundle.pem`.
- `hosts/NB2123/home.nix` (user, home-manager) — extracts the three env-var secrets, injects into `~/.claude/settings.json` (JWT + base URL) and `~/.yarnrc.yml` (PAT).

Both fetch the master password from Keychain (`security find-generic-password -a du234 -s kdbx-master`), so no interactive prompts.

## Corp gateway trust chain (TLS on VPN)

`/etc/nix/cert-bundle.pem` (built at system activation) is what the nix daemon (`nix.settings.ssl-cert-file`), npm (`cafile`), yarn (`httpsCaFilePath`), and Claude Code (`NODE_EXTRA_CA_CERTS`) all reference. Refresh cadence follows CA rotations in the KDBX vault — update the `corp/ca-bundle` attachment, rebuild, done.

The extraction runs in the user's Keychain session via `launchctl asuser $(id -u du234) sudo -u du234 <writeShellScript>`. When `security` searches for the master password from that context, `$HOME` is inherited from the root activate script (`~root`), so the keychain path must be passed explicitly (`/Users/du234/Library/Keychains/login.keychain-db`) — otherwise it looks in root's empty keychain.

## Rotating a secret

1. Edit the entry in KeePassXC (GUI or `keepassxc-cli edit`).
2. `sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#NB2123 --impure` — picks up the new value in one rebuild.

The Keychain-stored master password never changes for rotations; only the vault entries do.

## Manual steps (not nix-managed)

Do once after first rebuild:

- **Ice** — Settings → Advanced → "Launch Ice at Login" (SMAppService, not plist-backed)
- **alt-tab** — grant Accessibility permission (SIP-protected TCC.db)
- **Raycast** — open once; auto-registers as a login item
- **Claude Code** — `/theme light` (opted out of nix-codifying the theme)
- **macOS** — log out + back in once for the symbolic-hotkeys plist to take effect
