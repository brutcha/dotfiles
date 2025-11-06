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
hosts/          # Host-specific configurations
modules/        # Reusable modules
├── shared/     # Common across all hosts
├── darwin/     # macOS-specific modules
└── linux/      # Linux-specific modules
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
