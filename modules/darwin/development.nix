#
# MacOS development environment configuration
#
# Installs and configures development tools, editors, and version control systems
# 
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    docker
    lazydocker
    ghostty-bin
  ];

  imports = [
    ../shared/development.nix
  ];
}
