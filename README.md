# Dotfiles

Multi-platform nix configuration for macOS (nix-darwin) and Linux (NixOS) systems.

## Hosts

- **makima** (macOS, aarch64-darwin): Primary MacBook configuration
- **wintermute** (Linux, x86_64-linux): Gaming and homelab desktop setup

## Quick Start

### macOS (darwin-rebuild)
```bash
nix flake update
darwin-rebuild switch --flake .#makima
```

### Linux (nixos-rebuild)
```bash
sudo nixos-rebuild switch --flake .#wintermute
```

## Directory Structure

```
config/         # Static configuration files
├── nvim/       # Neovim configuration
└── sketchybar/ # SketchyBar Lua configuration
hosts/          # Host-specific configurations
├── makima/     # macOS laptop configuration
│   ├── default.nix  # System-level configuration
│   └── home.nix     # User-level home-manager configuration
└── wintermute/      # Linux desktop configuration
    └── default.nix  # System-level configuration
modules/        # Reusable modules
├── darwin/          # macOS system-level modules
│   └── minimal.nix  # Minimal macOS setup
└── home/            # User-level home-manager modules
    ├── development/ # Development tools and environment
    ├── window-manager/ # Window management (AeroSpace, SketchyBar, JankyBorders)
    ├── fonts.nix    # Font configuration
    ├── shell.nix    # Shell environment (zsh, starship, fzf, zoxide)
    ├── theme.nix    # Color theme configuration
    └── lib.nix      # Custom utilities and helper functions
```

## Window Management Stack

The macOS configuration includes a complete window management solution:

### [AeroSpace](https://nikitabobko.github.io/AeroSpace/)
- Tiling window manager for macOS with i3-like keybindings
- Workspace management integrated with SketchyBar
- Configurable gaps, layouts, and application rules

### [SketchyBar](https://felixkratz.github.io/SketchyBar/)
- Status bar replacement with comprehensive system monitoring
- Modular Lua-based configuration with separate files for each component
- Dynamic color generation from theme.nix to maintain consistency with Neovim
- Workspace indicators that integrate with AeroSpace window manager
- System monitoring for battery, network, RAM, and volume
- Conditional items that appear based on running applications
- Nerd Font icons with consistent styling

### [JankyBorders](https://github.com/FelixKratz/JankyBorders)
- Customizable window borders that complement the tiling window manager
- Dynamic border colors that match the color theme
- Configurable border widths and styles

To apply SketchyBar changes:
```bash
darwin-rebuild switch --flake .#makima
```

## Validation

```bash
nix flake check
```

## Build and Activate

### macOS
```bash
darwin-rebuild switch --flake .#makima
```

### Linux
```bash
sudo nixos-rebuild switch --flake .#wintermute
```

## Build Without Activating

### macOS
```bash
darwin-rebuild build --flake .#makima
```

### Linux
```bash
sudo nixos-rebuild build --flake .#wintermute
```

## Update Inputs

```bash
nix flake update
```

## Validate Configuration

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
