#
# Development environment configuration
#
# Installs and configures development tools, editors, and version control systems
# uses direnv for the per project environment setup
# https://github.com/nix-community/nix-direnv
# 
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    direnv
    lazygit
    tmux
  ];

  # direnv - per-project environment management with nix integration
  # Automatically loads project-specific dependencies based on .envrc file
  # https://nixos.org/manual/nixos/stable/options#opt-programs.direnv.enable
  programs = {
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };

  imports = [
    ./nvim.nix
  ];
}
