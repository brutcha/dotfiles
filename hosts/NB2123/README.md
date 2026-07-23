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
| `corp/azure-devops-mcp` | Password | Azure DevOps PAT (general/MCP scope) |
| `corp/azure-devops-npmrc` | Password | Azure DevOps Artifacts PAT (Packaging Read only) |
| `corp/azure-devops-release-token` | Password | Azure DevOps release-deploy PAT |
| `corp/codex-api-key` | Password | Personal WSO2 apiKey for the Codex proxy |
| `corp/codex-base-url` | Password | Codex proxy URL (e.g. `https://proxy.corp/v1/codex`) |
| `corp/ca-bundle` | Attachment `ca.pem` | Corp internal CA in PEM format |

```bash
DB=~/.config/dotfiles/vault.kdbx
keepassxc-cli mkdir "$DB" corp
keepassxc-cli add -p "$DB" corp/anthropic-jwt
keepassxc-cli add -p "$DB" corp/anthropic-base-url
keepassxc-cli add -p "$DB" corp/azure-devops-mcp
keepassxc-cli add -p "$DB" corp/azure-devops-npmrc
keepassxc-cli add -p "$DB" corp/azure-devops-release-token
keepassxc-cli add -p "$DB" corp/codex-api-key
keepassxc-cli add -p "$DB" corp/codex-base-url
keepassxc-cli add "$DB" corp/ca-bundle
keepassxc-cli attachment-import "$DB" corp/ca-bundle ca.pem /path/to/corp-ca.pem
```

### 2. Cache the KDBX master password in Keychain

```bash
security add-generic-password -a du234 -s kdbx-master -w '<KDBX master password>' -T /usr/bin/security
```

`-T /usr/bin/security` restricts the ACL to just the `security` binary, which is what our activation script uses. Prefer this over `-A` (allow any app), which is too permissive.

### 3. Create `private.nix` (non-secret host metadata)

```bash
mkdir -p ~/.config/dotfiles && chmod 0700 ~/.config/dotfiles
cp hosts/NB2123/private.example.nix ~/.config/dotfiles/private.nix
chmod 0600 ~/.config/dotfiles/private.nix
$EDITOR ~/.config/dotfiles/private.nix   # user identity + per-project entries
```

Expected fields: `user.{name,email}` and one entry per project under `projects.<name>` (each with `projectId`, `adoOrganization`, `packages`, and an optional `env` attrset). The project consumed by `registries.nix` for the `.yarnrc.yml` Azure Artifacts wiring must also carry `registryFeed` and `registryScope` — currently `projects.npaApp`. **No `secrets` attribute** — that's all in the vault now.

### 4. Rebuild

Two activations do the work:

- `cert-bundle.nix` (system) — extracts `corp/ca-bundle` via `launchctl asuser + sudo -u du234 keepassxc-cli`, merges with `/etc/ssl/cert.pem` into `/etc/nix/cert-bundle.pem`.
- `hosts/NB2123/home.nix` (user, home-manager) — extracts the env-var secrets and applies them:
  - Claude: injects `corp/anthropic-jwt` + `corp/anthropic-base-url` into `~/.claude/settings.json`. Each managed project's `<projectHome>/claude/settings.json` snapshot inherits these via the dev-shells activation; `project.mcpServers` from `private.nix` is jq-merged into `<projectHome>/claude/.claude.json.mcpServers` at the same time, with `authorization_env_var` and `$CORP_*` env refs resolved to literals from the activation env.
  - Codex: `~/.codex/config.toml` uses `base_url = "$CORP_CODEX_BASE_URL"`, resolved at activation by envsubst against a `$CORP_*` allowlist (unset refs stay as literal `$CORP_XXX` so Codex fails loudly instead of silently blanking). `codex login --with-api-key` then runs with `corp/codex-api-key` (fingerprint-gated — only re-runs on key rotation). Per-project `<projectHome>/codex/config.toml` files are produced by the dev-shells activation with the same envsubst pass; per-project `auth.json` is symlinked back to `~/.codex/auth.json`.
  - Azure DevOps: writes `corp/azure-devops-npmrc` (narrow Packaging-Read token) into `~/.yarnrc.yml`; `corp/azure-devops-mcp` is consumed by the per-project `azure-devops` MCP (see `dev-shells/corp-project.nix`), `corp/azure-devops-release-token` by the release-deploy env in `private.nix`.

All fetch the master password from Keychain (`security find-generic-password -a du234 -s kdbx-master`), so no interactive prompts.

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
- **Codex OAuth MCPs** — run `codex mcp login <name>` once per host for MCPs that need OAuth (`atlassian`, `figma`, …). Since per-project `auth.json` files symlink to `~/.codex/auth.json`, one login covers every project on this machine.
- **macOS** — log out + back in once for the symbolic-hotkeys plist to take effect
