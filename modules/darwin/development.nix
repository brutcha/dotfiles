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
  ];

  imports = [
    ../shared/development/default.nix
  ];
}
