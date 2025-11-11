#
# Multi-platform nix configuration for macOS (nix-darwin) and Linux (NixOS)
#
{
  description = "Multi-platform nix configuration for macOS (nix-darwin) and Linux (NixOS)";

  inputs = {
    # Nixpkgs unstable - packages and system utilities
    # https://github.com/NixOS/nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nix-darwin - macOS system configuration management
    # https://github.com/LnL7/nix-darwin
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # home-manager - user-level configuration management
    # https://github.com/nix-community/home-manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, home-manager, nixpkgs }:
  let
    # Custom utilities available globally as 'utils'
    utils = import ./modules/lib/default.nix { lib = nixpkgs.lib; };

    # Base configuration shared across all systems
    # Enables flakes and sets up fundamental packages
    configuration = { pkgs, ... }: {
      # Enable flakes support globally to use nix flake commands
      # https://github.com/NixOS/nix/blob/master/doc/manual/rl-next.md
      nix.settings.experimental-features = "nix-command flakes";

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

    # Helper function to create home-manager configuration for a user
    # Creates a module list that integrates home-manager with the system configuration
    # and imports user-specific settings from hosts/${hostname}/home.nix
    mkHomeConfig = { username, hostname, home }: [
      home-manager.darwinModules.home-manager
      {
        # Set the user's home directory path
        users.users.${username}.home = nixpkgs.lib.mkDefault home;

        # Use the system's nixpkgs instance for home-manager
        home-manager.useGlobalPkgs = true;
        # Install user packages to /etc/profiles instead of ~/.nix-profile
	      # Pass rootDir and custom utilities to home-manager
      	home-manager.extraSpecialArgs = {
	        rootDir = self;
          utils = utils;
	      };

        home-manager.useUserPackages = true;
        home-manager.users.${username} = {
          home.username = username;

          imports = [ 
            ./hosts/${hostname}/home.nix
          ];
        };
      }
    ];
   in
   {
     # macOS system configuration for Makima
     # Combines base configuration, system-level settings, and user-level home-manager config
     darwinConfigurations.makima = nix-darwin.lib.darwinSystem {
       specialArgs = { inherit utils; };
       modules = [
         configuration
         ./hosts/makima/default.nix
       ] ++ mkHomeConfig {
         username = "brutcha";
         hostname = "makima";
         home = "/Users/brutcha";
       };
     };
   };
}

