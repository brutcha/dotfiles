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
    ../../modules/shared/fonts.nix
    ../../modules/shared/shell.nix
    ../../modules/darwin/development.nix
    ../../modules/darwin/window-manager.nix
  ];
}
