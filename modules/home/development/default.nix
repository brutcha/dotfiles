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

  programs = {
    # direnv - per-project environment management with nix integration
    # Automatically loads project-specific dependencies based on .envrc file
    # https://nixos.org/manual/nixos/stable/options#opt-programs.direnv.enable
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    # ghostty - fast, native, cross-platform terminal emulator
    # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.ghostty.enable
    ghostty = {
      enable = true;
      enableZshIntegration = true;
      package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
      settings = {
        theme = "dark:TokyoNight Night,light:TokyoNight Day";
      };
    };
  };

  imports = [
    ./nvim.nix
  ];
}
