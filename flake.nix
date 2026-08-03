#
# Multi-platform nix configuration for macOS (nix-darwin) and Linux (NixOS)
#
{
  description = "Multi-platform nix configuration for macOS (nix-darwin) and Linux (NixOS)";

  inputs = {
    # Nixpkgs — rolling unstable channel
    # https://github.com/NixOS/nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nix-darwin - macOS system configuration management
    # https://github.com/LnL7/nix-darwin
    nix-darwin =
      {
        url = "github:nix-darwin/nix-darwin/master";
        inputs.nixpkgs.follows = "nixpkgs";
      };

    # home-manager - user-level configuration management
    # https://github.com/nix-community/home-manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-homebrew - Homebrew installation manager for nix-darwin
    # Manages Homebrew installation itself, works with nix-darwin's homebrew module
    # https://github.com/zhaofengli/nix-homebrew
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Claude Code plugins. flake = false because these repos are plain source
    # trees, not nix flakes. Update with `nix flake update <name>`.
    figma-plugin = {
      url = "github:figma/mcp-server-guide";
      flake = false;
    };
    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };

    # Helium browser (https://helium.computer) — Chromium-family, not in
    # nixpkgs. amaanq/helium-flake auto-updates versions.json every 15 min
    # from upstream imputnet/helium-{macos,linux} releases; we pin via
    # flake.lock and bump explicitly with `nix flake update helium-flake`.
    helium-flake = {
      url = "github:amaanq/helium-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- NixOS-only inputs (used by astoria) ---

    # nixos-hardware — per-model hardware quirks (Dell XPS 13 9300)
    # https://github.com/NixOS/nixos-hardware
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # disko — declarative disk partitioning (LUKS containers, Btrfs subvolumes)
    # https://github.com/nix-community/disko
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # sops-nix — activation-time secrets, encrypted-in-repo
    # https://github.com/Mic92/sops-nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NUR — Nix User Repository, for rycee.firefox-addons (enhanced-h264ify,
    # nextcloud-passwords). https://github.com/nix-community/NUR
    nur.url = "github:nix-community/NUR";

    # Lanzaboote — signed systemd-boot replacement (Secure Boot chain). Pinned
    # to the release tag rather than main because it's a boot-chain-critical
    # dependency and unpinned bumps can brick unattended updates. v1.1.0
    # (released 2026-06-22) is the first tag compatible with post-2026-06-09
    # nixpkgs where `boot.bootspec.enable` was removed.
    # https://github.com/nix-community/lanzaboote
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, home-manager, nix-homebrew, nixpkgs, ... }:
    let
      # Custom utilities available globally as 'helpers'. Must not be named
      # `utils` — NixOS's module framework injects its own internal `utils` arg.
      helpers = import ./modules/lib/default.nix { lib = nixpkgs.lib; };

      # Darwin host-wiring helpers (module-list and pkgs builders used by
      # darwinConfigurations.* below) — see modules/lib/darwin-hosts.nix
      darwinHosts = import ./modules/lib/darwin-hosts.nix { lib = nixpkgs.lib; };

      # Base configuration shared across all systems
      # Enables flakes and sets up fundamental packages
      configuration = { pkgs, ... }: {
        # Enable flakes support globally to use nix flake commands
        # https://github.com/NixOS/nix/blob/master/doc/manual/rl-next.md
        nix.settings.experimental-features = ["nix-command" "flakes"];

        # Flake-only setup — drop the legacy channels path from NIX_PATH
        # (silences "Nix search path entry .../channels does not exist").
        nix.channel.enable = false;

        # Allow unfree packages
        nixpkgs.config.allowUnfree = true;

        # Track git commit hash for reproducibility and version tracking
        # https://github.com/LnL7/nix-darwin/blob/master/modules/system/defaults.nix
        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Foundational packages available to all hosts and users
        # Search for packages: https://search.nixos.org
        environment.systemPackages = with pkgs; [
          vim
          git
          zsh
          coreutils
          gnupg
        ];
      };

      # Per-project dev shells (sidecar pattern)
      # ----------------------------------------
      # The dotfiles install no node-version-manager. Per-project shells are
      # delivered as flake-based sidecars under
      # ~/.local/share/dev-shells/<project>, materialized by home.activation
      # scripts in modules/home/development/dev-shells/ (we don't use
      # xdg.configFile because `nix flake` doesn't resolve symlinked
      # flake.nix correctly inside an otherwise-real source dir). Each
      # cloned project gets an `.envrc` that says
      # `use flake ~/.local/share/dev-shells/<project>`, and direnv
      # (modules/home/development/default.nix) activates it on `cd`.
      # `.envrc` is hidden via the global gitignore in
      # modules/home/development/git.nix, so nothing about this setup leaks
      # into the project's own .gitignore. See dev-shells/default.nix for
      # the full mechanism, inheritance rules, and future privacy options.

    in
    {
      # Re-export disko's CLI at the flake's own package output so the
      # astoria README can invoke it as `sudo nix run '.#disko' -- ...`
      # from the cloned repo — that hits our lock-pinned commit rather
      # than `github:nix-community/disko` HEAD.
      packages.x86_64-linux.disko = inputs.disko.packages.x86_64-linux.disko;

      # macOS system configuration for makima (personal MacBook)
      darwinConfigurations.makima =
        let
          username = "pavla";
          hostname = "makima";
          system = "aarch64-darwin";

          # Per-host private values — template: hosts/makima/private.example.nix
          # (nix's pathExists under sudo is unreliable; let `import` fail with a
          # clearer file-not-found message if the file is missing)
          private = import "/Users/${username}/.config/dotfiles/private.nix";
          pkgs = darwinHosts.mkDarwinPkgs { inherit nixpkgs system helpers rootDir; };
          rootDir = self;
        in
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit helpers pkgs rootDir private; };

          modules = [
            configuration
            ./hosts/${hostname}/default.nix
          ] ++ darwinHosts.mkHomeConfig {
            inherit home-manager inputs rootDir helpers;
            inherit username hostname private system;
            home = "/Users/${username}";
          } ++ darwinHosts.mkHomebrewConfig {
            inherit nix-homebrew username;
            autoMigrate = true;
          };
        };

      # macOS system configuration for NB2123 (work MacBook)
      darwinConfigurations.NB2123 =
        let
          # Host-specific configuration variables
          # Defined here to keep them scoped to this specific host configuration
          username = "du234";
          hostname = "NB2123";
          system = "aarch64-darwin";

          # Per-host private values — template: hosts/NB2123/private.example.nix
          # (nix's pathExists under sudo is unreliable; let `import` fail with a
          # clearer file-not-found message if the file is missing)
          private = import "/Users/${username}/.config/dotfiles/private.nix";
          pkgs = darwinHosts.mkDarwinPkgs { inherit nixpkgs system helpers rootDir; };
          rootDir = self;
        in
        nix-darwin.lib.darwinSystem {
          inherit system;
          # Add helpers to the nix flake specialArgs, make helpers like toARGB available in each module
          specialArgs = { inherit helpers pkgs rootDir private; };

          modules = [
            configuration
            ./hosts/${hostname}/default.nix
          ] ++ darwinHosts.mkHomeConfig {
            inherit home-manager inputs rootDir helpers;
            inherit username hostname private system;
            home = "/Users/${username}";
          } ++ darwinHosts.mkHomebrewConfig {
            inherit nix-homebrew username;
            autoMigrate = true;
          };
        };

      # NixOS system configuration for astoria (Dell XPS 13 9300 thin-client)
      #
      # `inputs` MUST be threaded into BOTH system specialArgs (for
      # hosts/astoria/{default,hardware}.nix which pattern-match `{ inputs, ... }:`)
      # AND `home-manager.extraSpecialArgs` (for shared HM modules like
      # modules/home/development/dev-shells/default.nix and claude-code.nix which
      # also eagerly destructure `{ inputs, ... }:`). System specialArgs do NOT
      # propagate into HM's module scope — the second wiring below is not
      # optional; without it HM eval fails "attribute 'inputs' missing" at
      # pattern-match, before any lib.mkIf gate can fire.
      #
      # `private = null` is safe: the modules that consume it all use `private ?
      # null` at pattern-match. Passing null explicitly keeps parity with the
      # darwin wiring pattern so any future extraction/dedup stays trivial.
      nixosConfigurations.astoria =
        let
          system = "x86_64-linux";
          private = null;
          rootDir = self;
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs rootDir private helpers; };
          modules = [
            configuration
            ./hosts/astoria/default.nix
            {
              home-manager.extraSpecialArgs = {
                inherit inputs private rootDir helpers;
                hostSystem = system;
              };
            }
          ];
        };
    };
}
