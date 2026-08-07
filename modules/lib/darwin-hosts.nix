{ lib }:
#
# Darwin host-wiring helpers
#
# Functions that assemble nix-darwin module lists and pkgs instantiations for
# a host's `darwinConfigurations.<name>` block in flake.nix. Unlike
# modules/lib/default.nix (whose `colors`/`darwin` helpers are threaded into
# module bodies via the `helpers` specialArg), these functions are consumed
# ONLY by flake.nix itself, before any specialArgs wiring happens.
#
# Because they build module lists and pkgs sets rather than being pure config
# utilities, every value they'd otherwise close over (home-manager,
# nix-homebrew, nixpkgs, inputs, rootDir, helpers) is passed in explicitly by
# the caller in flake.nix — including `helpers` itself, since this file
# cannot reference the `helpers` binding it is a sibling of.
#
{
  # Build the home-manager module list for a darwin host
  #
  # Integrates home-manager with the system configuration and imports
  # user-specific settings from hosts/${hostname}/home.nix.
  #
  # Arguments:
  #   home-manager - The home-manager flake input (darwinModules.home-manager)
  #   inputs       - The flake's full `inputs` attrset, threaded into extraSpecialArgs
  #   rootDir      - The flake's `self`, threaded into extraSpecialArgs and used
  #                  to build an absolute path to hosts/${hostname}/home.nix
  #                  (a relative `./hosts/...` path here would resolve against
  #                  this file's own directory, not the flake root)
  #   helpers      - The `helpers` value from modules/lib/default.nix, threaded
  #                  into extraSpecialArgs
  #   username     - The user account this home-manager config applies to
  #   hostname     - Host directory name under hosts/, used to locate home.nix
  #   home         - Absolute path to the user's home directory
  #   system       - Nix system string (e.g. "aarch64-darwin"), threaded as hostSystem
  #   private      - Per-host private values (default null)
  #
  # Returns:
  #   A list of modules to append to a darwinSystem's `modules`
  #
  # Example:
  #   darwinHosts.mkHomeConfig {
  #     inherit home-manager inputs rootDir helpers;
  #     username = "pavla"; hostname = "makima"; system = "aarch64-darwin";
  #     home = "/Users/pavla";
  #   }
  #
  mkHomeConfig = { home-manager, inputs, rootDir, helpers, username, hostname, home, system, private ? null }: [
    home-manager.darwinModules.home-manager
    {
      # Set the user's home directory path
      users.users.${username}.home = lib.mkDefault home;

      # Use the system's nixpkgs instance for home-manager
      home-manager.useGlobalPkgs = true;
      # Install user packages to /etc/profiles instead of ~/.nix-profile.
      # `private` is always present (null on hosts without one) so modules
      # can pattern-match on it without triggering _module.args recursion.
      #
      # `hostSystem` is the Nix system string ("aarch64-darwin",
      # "x86_64-linux", ...). Threaded via specialArgs so modules/home
      # can decide platform sub-bundle imports (see modules/home/default.nix)
      # without depending on `pkgs.stdenv.hostPlatform.*` at import-list
      # eval time — that route hits `_module.args`->`config` recursion
      # because pkgs isn't externally provided to HM's inner modules.
      home-manager.extraSpecialArgs = {
        inherit inputs private helpers;
        hostSystem = system;
        rootDir = rootDir;
      };

      home-manager.useUserPackages = true;

      # When a file home-manager wants to manage already exists (e.g.
      # KeePassXC writes its own keepassxc.ini before we declare it),
      # move the existing file to `<name>.backup` instead of aborting.
      home-manager.backupFileExtension = "backup";

      home-manager.users.${username} = {
        home.username = username;

        imports = [
          (rootDir + "/hosts/${hostname}/home.nix")
        ];
      };
    }
  ];

  # Build the nix-homebrew module list for a darwin host
  #
  # Creates a module list that integrates nix-homebrew with the system
  # configuration. nix-homebrew manages Homebrew installation itself, while
  # nix-darwin's homebrew module manages packages declaratively.
  #
  # Arguments:
  #   nix-homebrew - The nix-homebrew flake input (darwinModules.nix-homebrew)
  #   username     - The user who owns the Homebrew installation
  #   taps         - Optional attrset of Homebrew taps to manage declaratively
  #   autoMigrate  - Whether to automatically migrate an existing Homebrew
  #                  installation
  #
  # Returns:
  #   A list of modules to append to a darwinSystem's `modules`
  #
  # Example:
  #   darwinHosts.mkHomebrewConfig { inherit nix-homebrew; username = "pavla"; }
  #
  mkHomebrewConfig = { nix-homebrew, username, taps ? { }, autoMigrate ? true }: [
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

  # Build the pkgs instantiation for a darwin host
  #
  # Wraps `import nixpkgs { ... }` with the overlays every darwin host needs:
  # a fish `doCheck = false` override (fish's test suite doesn't pass in our
  # darwin build environment) and our own ./pkgs overlay.
  #
  # Arguments:
  #   nixpkgs     - The nixpkgs flake input
  #   system      - Nix system string (e.g. "aarch64-darwin")
  #   helpers     - The `helpers` value from modules/lib/default.nix, passed
  #                 through to the ./pkgs overlay
  #   rootDir     - The flake's `self`, used to build an absolute path to
  #                 ./pkgs (a relative path here would resolve against this
  #                 file's own directory, not the flake root)
  #   allowUnfree - Whether to allow unfree packages (default true)
  #   overlays    - Extra host-specific overlays, applied after the shared ones
  #
  # Returns:
  #   An instantiated nixpkgs set
  #
  # Example:
  #   darwinHosts.mkDarwinPkgs { inherit nixpkgs system helpers rootDir; }
  #
  mkDarwinPkgs = { nixpkgs, system, helpers, rootDir, allowUnfree ? true, overlays ? [ ] }:
    import nixpkgs {
      inherit system;
      config = { inherit allowUnfree; };
      overlays = [
        (final: prev: {
          fish = prev.fish.overrideAttrs (old: { doCheck = false; });
        })
        (import (rootDir + "/pkgs") { inherit helpers; })
      ] ++ overlays;
    };
}
