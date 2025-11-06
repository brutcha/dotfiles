#
# Cross-platform font configuration
#
# Installs and configures fonts for use across the system
#
{ pkgs, ... }:
{
  # Install nerd fonts with monospace variants for terminal and editor use
  # https://www.nerdfonts.com/
  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # Enable fontconfig for proper font discovery and rendering across applications
  # https://nix-community.github.io/home-manager/options.xhtml#opt-fonts.fontconfig.enable
  fonts.fontconfig.enable = true;
}
