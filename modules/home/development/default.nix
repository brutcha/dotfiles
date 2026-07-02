{ config, lib, pkgs, ... }:
#
# Development tools
#
# Available options:
# - home.apps.development.direnv.enable  - per-project shell activation (nix-direnv)
# - home.apps.development.ghostty.enable - terminal emulator
# - home.apps.development.lazygit.enable - git TUI
# - home.apps.development.tmux.enable    - terminal multiplexer
#
let
  cfg = config.home.apps.development;
in
{
  imports = [
    ./nvim.nix
    ./claude-code.nix
    ./rtk.nix
    ./git.nix
    ./zed.nix
    ./dev-shells
  ];

  options.home.apps.development = {
    direnv.enable = lib.mkEnableOption "direnv with nix-direnv";
    ghostty.enable = lib.mkEnableOption "Ghostty terminal";
    lazygit.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.home.apps.development.git.enable;
      description = "lazygit TUI. Auto-enables when git is enabled.";
    };
    tmux.enable = lib.mkEnableOption "tmux";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.direnv.enable {
      programs.direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };
    })

    (lib.mkIf cfg.ghostty.enable {
      programs.ghostty = {
        enable = true;
        enableZshIntegration = true;
        package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
        settings.theme = "dark:TokyoNight Night,light:TokyoNight Day";
      };
    })

    (lib.mkIf cfg.lazygit.enable {
      home.packages = [ pkgs.lazygit ];
    })

    (lib.mkIf cfg.tmux.enable {
      home.packages = [ pkgs.tmux ];
    })
  ];
}
