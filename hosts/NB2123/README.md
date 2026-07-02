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

Per-machine identity + corp secrets live in `~/.config/dotfiles/private.nix` (never committed). Create from the template:

```bash
mkdir -p ~/.config/dotfiles && chmod 0700 ~/.config/dotfiles
cp hosts/NB2123/private.example.nix ~/.config/dotfiles/private.nix
chmod 0600 ~/.config/dotfiles/private.nix
$EDITOR ~/.config/dotfiles/private.nix   # fill in name/email/JWT/PAT/CA PEM
```

Expected fields: `user.{name,email}`, `npa.{projectId,adoOrganization,registryFeed,registryScope}`, `secrets.{anthropicBaseUrl,anthropicJwt,azureDevopsPat,corpCaBundlePem}`.

## Corp gateway trust chain (TLS on VPN)

`cert-bundle.nix` concatenates the system CA bundle (`/etc/ssl/cert.pem`) with the corp CA from `private.secrets.corpCaBundlePem` into `/etc/nix/cert-bundle.pem` on every activation. That single bundle is what the nix daemon (`nix.settings.ssl-cert-file`), npm (`cafile`), yarn (`httpsCaFilePath`), and Claude Code (`NODE_EXTRA_CA_CERTS`) all reference.

The CA is baked into the activation script at eval time, so the first rebuild materializes it in the same pass — no bootstrap dance needed.

## Manual steps (not nix-managed)

Do once after first rebuild:

- **Ice** — Settings → Advanced → "Launch Ice at Login" (SMAppService, not plist-backed)
- **alt-tab** — grant Accessibility permission (SIP-protected TCC.db)
- **Raycast** — open once; auto-registers as a login item
- **Claude Code** — `/theme light` (opted out of nix-codifying the theme)
- **macOS** — log out + back in once for the symbolic-hotkeys plist to take effect
