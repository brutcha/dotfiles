#
# Makima home-manager configuration (user-level)
#
# This configuration is applied to the user specified in hosts/makima/default.nix
# System-level configuration is in ./default.nix
#
{
  # State version - should match the Home Manager version you first installed
  # Do not change this after initial setup unless you read the release notes
  # https://nix-community.github.io/home-manager/index.xhtml#sec-install-nix-darwin-module
  home.stateVersion = "25.05";

  # Import user-level modules
  # https://nix-community.github.io/home-manager/
  imports = [
    ../../modules/home/theme.nix
    ../../modules/home/fonts.nix
    ../../modules/home/shell.nix
    ../../modules/home/internet
    ../../modules/home/development/darwin.nix
    ../../modules/home/window-manager/darwin.nix
  ];
}
