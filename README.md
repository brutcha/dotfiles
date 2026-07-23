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

```text
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
    ├── development/    # Cross-platform dev: direnv, ghostty, nvim, git, rtk, zed, claude-code, codex, dev-shells/
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

- `modules/home/development/dev-shells/corp-project.nix` is the reusable per-project module. `default.nix` iterates over `private.projects` and instantiates it once per entry — adding a project is a `private.nix` edit, not a dotfiles change
- Each activation materializes real (non-symlink) `flake.nix`, `.envrc`, `.emdash.json`, and `env.sh` under `~/.local/share/dev-shells/<projectId>/`, then copies `.envrc` + `.emdash.json` into `~/git/<projectId>/` as real files (emdash's `preservePatterns` doesn't follow symlinks into worktrees)
- `env.sh` is written by the activation via unquoted heredoc (chmod 0600). `project.env` values that reference `$CORP_*` variables are expanded from whatever `keepassSecretsExtract` has exported — same channel as `registries.nix`
- `.envrc` and `.emdash.json` are hidden by the global gitignore (`modules/home/development/git.nix` + `~/.config/git/ignore`)
- `project.mcpServers` is a data-driven attrset consumed by both agents. Each project gets its own `<projectHome>/<agent>/` home with entries jq-merged into a config the agent reads directly, and direnv exports the agent's home env var so terminals AND Emdash worktrees (`shellSetup = eval "$(direnv export bash)"`) resolve to it automatically:
  - **Codex** — `<projectHome>/codex/config.toml` (host-globals + per-project MCPs), `CODEX_HOME` env var, and `<projectHome>/codex/auth.json` symlinked back to `~/.codex/auth.json` so a single `codex login` covers every project
  - **Claude** — `<projectHome>/claude/settings.json` (a snapshot of `~/.claude/settings.json`, produced after `claudeCodeSettings`/`claudeCodeCorpSecrets`/`rtkInit` run, with `project.mcpServers` jq-merged on top so env/plugins/RTK hook/JWT all inherit), `CLAUDE_CONFIG_DIR` env var, and `plugins`/`skills`/`CLAUDE.md`/`RTK.md` symlinked from `~/.claude/` so upstream edits propagate. `.claude.json`, `projects/` (sessions), and caches are per-project — Claude creates them on first launch

Why `home.activation` instead of `xdg.configFile`? home-manager writes `xdg.configFile` entries as symlinks into the nix store, but `nix flake` doesn't resolve a symlinked `flake.nix` inside an otherwise-real source directory — it generates a nested store path that doesn't exist. The activation script is the workaround.

Sidecars inherit `inputs.nixpkgs.rev` and `pkgs.stdenv.hostPlatform.system` from the parent flake, so the same module works unchanged on darwin and (future) NixOS hosts.

### Adding a New Project
1. Add an entry to `projects.<name>` in `~/.config/dotfiles/private.nix` — see `hosts/NB2123/private.example.nix` for the required fields (`projectId`, `adoOrganization`, `packages`, `env`).
2. Rebuild — sidecar files are materialized and copied into `~/git/<projectId>/` automatically.

## Git Configuration

`modules/home/development/git.nix` provides:

- **Global gitignore** (`programs.git.ignores`) — `.envrc`, `.direnv/`, `.emdash.json` so per-project tooling files never appear in `git status` of repos you don't own
- **git-credential-manager** — browser-based OAuth for Azure DevOps and GitHub HTTPS clones, with tokens cached in the macOS keychain (or Secret Service on Linux)
- **Identity via `includes`** — any `github.com/brutcha/*` remote picks up the brutcha identity automatically

Host-specific extras layer on top per host, e.g. the corp CA bundle path and Azure DevOps `useHttpPath` scoping in `hosts/NB2123/home.nix`. Per-project identity overrides are wired by `corp-project.nix`: for each entry in `private.projects` it appends a `programs.git.includes` block with an `includeIf` matching the checkout path, so any commit from `~/git/<projectId>/` picks up `private.user.{name,email}` automatically.

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
