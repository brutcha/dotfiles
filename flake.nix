#
# Multi-platform nix configuration for macOS (nix-darwin) and Linux (NixOS)
#
{
  description = "Multi-platform nix configuration for macOS (nix-darwin) and Linux (NixOS)";

  inputs = {
    # Nixpkgs pinned to specific commit
    # Pinned to avoid fish 4.2.1 test failures on macOS (uses fish 4.1.2)
    # To update: change to "nixpkgs-unstable" and run nix flake update
    # https://github.com/NixOS/nixpkgs
    # nixpkgs.url = "github:NixOS/nixpkgs/91c9a64ce2a84e648d0cf9671274bb9c2fb9ba60";
    nixpkgs.url = "github:NixOs/nixpkgs/nixpkgs-unstable";

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
  };

  outputs = inputs@{ self, nix-darwin, home-manager, nix-homebrew, nixpkgs, ... }:
    let
      # Custom utilities available globally as 'utils'
      utils = import ./modules/lib/default.nix { lib = nixpkgs.lib; };

      # Base configuration shared across all systems
      # Enables flakes and sets up fundamental packages
      configuration = { pkgs, ... }: {
        # Enable flakes support globally to use nix flake commands
        # https://github.com/NixOS/nix/blob/master/doc/manual/rl-next.md
        nix.settings.experimental-features = "nix-command flakes";

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

      # Helper function to create home-manager configuration for a user
      # Creates a module list that integrates home-manager with the system configuration
      # and imports user-specific settings from hosts/${hostname}/home.nix
      mkHomeConfig = { username, hostname, home, private ? null }: [
        home-manager.darwinModules.home-manager
        {
          # Set the user's home directory path
          users.users.${username}.home = nixpkgs.lib.mkDefault home;

          # Use the system's nixpkgs instance for home-manager
          home-manager.useGlobalPkgs = true;
          # Install user packages to /etc/profiles instead of ~/.nix-profile.
          # `private` is always present (null on hosts without one) so modules
          # can pattern-match on it without triggering _module.args recursion.
          home-manager.extraSpecialArgs = {
            inherit inputs private;
            rootDir = self;
            utils = utils;
          };

          home-manager.useUserPackages = true;

          # When a file home-manager wants to manage already exists (e.g.
          # KeePassXC writes its own keepassxc.ini before we declare it),
          # move the existing file to `<name>.backup` instead of aborting.
          home-manager.backupFileExtension = "backup";

          home-manager.users.${username} = {
            home.username = username;

            imports = [
              ./hosts/${hostname}/home.nix
            ];
          };
        }
      ];

      # Helper function to create nix-homebrew configuration for a user
      # Creates a module list that integrates nix-homebrew with the system configuration
      # nix-homebrew manages Homebrew installation itself, while nix-darwin's homebrew
      # module manages packages declaratively.
      #
      # Parameters:
      # - username: The user who owns the Homebrew installation
      # - taps: Optional attribute set of Homebrew taps to manage declaratively
      # - autoMigrate: Whether to automatically migrate existing Homebrew installations
      #
      # Homebrew integration approach:
      # - Uses nix-homebrew to manage Homebrew installation itself
      # - Uses nix-darwin's homebrew.* options to manage packages declaratively
      # - Works with existing Homebrew installations via autoMigrate
      mkHomebrewConfig = { username, taps ? { }, autoMigrate ? true }: [
        nix-homebrew.darwinModules.nix-homebrew
        {
          # Set the primary user for nix-darwin
          system.primaryUser = username;

          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = username;
            taps = taps;
            mutableTaps = true;
            autoMigrate = autoMigrate;
          };
        }
      ];
    in
    {
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
          pkgs = import nixpkgs {
            inherit system;
            config = { allowUnfree = true; };
            overlays = [
              (final: prev: {
                fish = prev.fish.overrideAttrs (old: { doCheck = false; });
              })
              (import ./pkgs { inherit utils; })
            ];
          };
          rootDir = self;
        in
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit utils pkgs rootDir private; };

          modules = [
            configuration
            ./hosts/${hostname}/default.nix
          ] ++ mkHomeConfig {
            inherit username hostname private;
            home = "/Users/${username}";
          } ++ mkHomebrewConfig {
            inherit username;
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
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
            };
            overlays = [
              (final: prev: {
                fish = prev.fish.overrideAttrs (old: {
                  doCheck = false;
                });
              })
              (import ./pkgs { inherit utils; })
            ];
          };
          rootDir = self;
        in
        nix-darwin.lib.darwinSystem {
          inherit system;
          # Add utils to the nix flake specialArgs, make helpers like toARGB available in each module
          specialArgs = { inherit utils pkgs rootDir private; };

          modules = [
            configuration
            ./hosts/${hostname}/default.nix
          ] ++ mkHomeConfig {
            inherit username hostname private;
            home = "/Users/${username}";
          } ++ mkHomebrewConfig {
            inherit username;
            autoMigrate = true;
          };
        };
    };
}


