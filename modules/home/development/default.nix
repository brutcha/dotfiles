{ config, lib, pkgs, ... }:
#
# Development tools
#
# Available options:
# - home.apps.development.direnv.enable     - per-project shell activation (nix-direnv)
# - home.apps.development.ghostty.enable    - terminal emulator
# - home.apps.development.lazygit.enable    - git TUI
# - home.apps.development.tmux.enable       - terminal multiplexer
# - home.apps.development.azure-cli.enable  - Azure Command-Line Interface
#
let
  cfg = config.home.apps.development;
in
{
  imports = [
    ./nvim.nix
    ./claude-code.nix
    ./codex.nix
    ./opencode.nix
    ./podman.nix
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
    workmux.enable = lib.mkEnableOption "Workmux global configuration";
    azure-cli.enable = lib.mkEnableOption "azure-cli";
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
        package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
        settings = {
          theme = "dark:TokyoNight Night,light:TokyoNight Day";
          # Make Shift+Enter distinct from Enter for tmux's CSI-u extended-key
          # forwarding and agent TUIs that use it for a newline.
          keybind = [ "shift+enter=csi:13;2u" ];
        }
        # Linux only: darwin has no PRIMARY, false there kills select-to-copy.
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          copy-on-select = false;
        };
      };
    })

    (lib.mkIf cfg.lazygit.enable {
      home.packages = [ pkgs.lazygit ];
    })

    (lib.mkIf cfg.tmux.enable {
      # Forward modified keys (notably Shift+Enter) through tmux using CSI-u.
      # Agent TUIs use this to distinguish a newline from prompt submission.
      programs.tmux = {
        enable = true;
        extraConfig = ''
          set -g extended-keys always
          set -g extended-keys-format csi-u
          # OpenCode currently treats CSI-u Shift+Enter as Return. Translate
          # it to the Ctrl+J newline shortcut that its terminal parser accepts.
          bind-key -n S-Enter if-shell -F '#{==:#{pane_current_command},opencode}' 'send-keys C-j' 'send-keys S-Enter'
          # Workmux's sidebar uses mouse clicks to focus an agent pane.
          set -g mouse on
        '';
      };
    })

    (lib.mkIf cfg.workmux.enable {
      # The Workmux binary comes from its vendor Homebrew tap; Home Manager
      # owns only the global configuration.
      xdg.configFile."workmux/config.yaml" = {
        force = true;
        text = ''
          agent: opencode
          nerdfont: true
          # Keep every worktree as a window in the tmux session from which it
          # was launched (normally `workmux` via the `wmux` alias). This avoids
          # spawning one tmux session per project or worktree.
          mode: window
          sidebar:
            position: left
            width: 36
            layout: tiles
            group_by: project
            sort: window
            enter_action: focus
        '';
      };
    })
    
    (lib.mkIf cfg.azure-cli.enable {
      home.packages = [ pkgs.azure-cli ];
    })
  ];
}
