# Dotfiles

Multi-platform nix configuration for macOS (nix-darwin) and Linux (NixOS) systems.

## Hosts

- **[NB2123](./hosts/NB2123/README.md)** (macOS, aarch64-darwin): Work MacBook — corporate gateway, private.nix
- **makima** (macOS, aarch64-darwin): Personal MacBook
- **wintermute** (Linux, x86_64-linux): Gaming and homelab desktop setup (not yet declared)

## Quick Start

Each host has its own rebuild recipe. See the host's README for the exact command and any per-host setup — [NB2123](./hosts/NB2123/README.md).

General shape:

```bash
# macOS
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#<hostname>

# Linux
sudo nixos-rebuild switch --flake .#<hostname>
```

## Directory Structure

```
config/          # Static configuration files
├── nvim/           # Neovim configuration
└── sketchybar/     # SketchyBar Lua configuration
hosts/           # Host-specific configurations
├── NB2123/         # macOS work laptop (see hosts/NB2123/README.md)
├── makima/         # macOS personal laptop
└── wintermute/     # Linux desktop (planned)
modules/         # Reusable modules
├── darwin/         # macOS system-level modules (nix-darwin)
│   └── minimal.nix     # Shared macOS setup, apps
└── home/           # User-level home-manager modules
    ├── default.nix     # Shared aggregator (platform-generic)
    ├── theme.nix / fonts.nix / shell.nix
    ├── development/    # Cross-platform dev: direnv, ghostty, nvim, git, rtk, zed, claude-code, dev-shells/
    └── darwin/         # macOS-only bundle (imports shared + darwin-only extras)
        ├── default.nix        # Aggregator + LaunchServices registration
        ├── development.nix    # lazydocker, xcbuild
        ├── internet/helium.nix
        ├── security/keepass.nix
        └── window-manager/    # AeroSpace, SketchyBar, JankyBorders
```

Hosts on macOS import a single path: `../../modules/home/darwin`. A non-darwin host would import `../../modules/home` directly (shared modules only). Each darwin-only module carries a `lib.mkIf pkgs.stdenv.hostPlatform.isDarwin` guard in its config block for defense in depth.

## Window Management Stack

Opt-in per host (all three modules default to disabled).

### [AeroSpace](https://nikitabobko.github.io/AeroSpace/)
Tiling window manager with i3-like keybindings. Workspace management integrated with SketchyBar.

### [SketchyBar](https://felixkratz.github.io/SketchyBar/)
Status bar replacement. Modular Lua-based configuration, dynamic color generation from `theme.nix`, workspace indicators bound to AeroSpace, and system-monitor items (battery, network, RAM, volume).

### [JankyBorders](https://github.com/FelixKratz/JankyBorders)
Window borders that follow the color theme.

## Homebrew Integration

The macOS configuration uses [nix-homebrew](https://github.com/zhaofengli/nix-homebrew) with automatic cask detection.

- Custom packages in `pkgs/` use `utils.darwin.mkBrewCask` to create Homebrew cask markers
- Modules add packages to `environment.systemPackages` as usual (no Homebrew-specific code needed)
- `modules/darwin/homebrew.nix` detects packages with `passthru.brewCask` and adds them to `homebrew.casks`
- Casks install via Homebrew on system rebuild (source unified in `pkgs/`, no sha256 tracking)

## Per-Project Dev Shells

No node-version-manager is installed. Each project gets a flake-based sidecar shell delivered via home-manager and activated by direnv on `cd`.

- Sidecar modules live in `modules/home/development/dev-shells/`
- Each module materializes a real (non-symlink) `flake.nix` via `home.activation` — file content built with `pkgs.writeText`, copied to `~/.local/share/dev-shells/<project>/flake.nix`
- The cloned project gets a one-line `.envrc`: `use flake ~/.local/share/dev-shells/<project>`
- `.envrc` is hidden by the global gitignore in `modules/home/development/git.nix`

Why `home.activation` instead of `xdg.configFile`? home-manager writes `xdg.configFile` entries as symlinks into the nix store, but `nix flake` doesn't resolve a symlinked `flake.nix` inside an otherwise-real source directory — it generates a nested store path that doesn't exist. The activation script is the workaround.

Sidecars inherit `inputs.nixpkgs.rev` and `pkgs.stdenv.hostPlatform.system` from the parent flake, so the same module works unchanged on darwin and (future) NixOS hosts.

### Adding a New Project
1. Create `modules/home/development/dev-shells/<name>.nix` following the pattern in `corp-npa.nix`
2. Add it to the `sidecars` list in `dev-shells/default.nix`
3. Rebuild — flake.nix + .envrc + .emdash.json are staged and symlinked into `~/git/<projectId>/` automatically

## Git Configuration

`modules/home/development/git.nix` provides:

- **Global gitignore** (`programs.git.ignores`) — `.envrc`, `.direnv/`, `.emdash.json` so per-project tooling files never appear in `git status` of repos you don't own
- **git-credential-manager** — browser-based OAuth for Azure DevOps and GitHub HTTPS clones, with tokens cached in the macOS keychain (or Secret Service on Linux)
- **Identity via `includes`** — any `github.com/brutcha/*` remote picks up the brutcha identity automatically

Host-specific extras layer on top per host, e.g. the corp CA bundle path and Azure DevOps `useHttpPath` scoping in `hosts/NB2123/home.nix`. Per-project identity overrides sit next to the project's own dev-shell module (e.g. `corp-npa.nix` sets the Creditas identity via `includeIf`).

## Update Inputs

```bash
nix flake update                       # bump everything
nix flake update nixpkgs               # bump just nixpkgs
./scripts/check-cache.sh               # verify aarch64-darwin cache before rebuilding
```

`nixpkgs-unstable` advances after Hydra's channel-tested job set passes, but heavy darwin builds (mono, dotnet-sdk, electron, …) aren't always in that set, so `cache.nixos.org` can miss aarch64-darwin binaries. `check-cache.sh` probes a watchlist (top of the file) of known-heavy packages and reports cached / not-cached. If a watched package is missing, either roll back `flake.lock`, override it in `pkgs/<name>/default.nix` (brew marker via `utils.darwin.mkBrewCask`, or a custom `.dmg`/AppImage fetch), or accept a one-time source build.

## Custom Package Updates

### Homebrew Casks (automatic)
Packages using `utils.darwin.mkBrewCask` are updated by Homebrew on `darwin-rebuild switch` — no manual intervention.

### Manual Package Updates
For packages not using Homebrew:

```bash
nix run nixpkgs#nix-update -- <package-name> --version=<NEW_VERSION>
```

## Validate

```bash
nix flake check
```

## Search Packages

```bash
nix search nixpkgs <package-name>
```

## References

- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [home-manager](https://nix-community.github.io/home-manager/)
- [nixpkgs search](https://search.nixos.org)
- [Nix Flakes](https://wiki.nixos.org/wiki/Flakes)
- [SketchyBar](https://felixkratz.github.io/SketchyBar/)
- [AeroSpace](https://nikitabobko.github.io/AeroSpace/)
