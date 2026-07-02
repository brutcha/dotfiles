{ config, lib, ... }:
#
# Zed editor (https://zed.dev)
#
# Available options:
# - home.apps.development.zed.enable - Install Zed and merge declared settings
#
# settings.json stays writable (mutableUserSettings = true by default) so
# UI changes persist between rebuilds; declared `userSettings` keys are
# re-asserted on each rebuild via jq deep-merge.
#
let
  cfg = config.home.apps.development.zed;
in
{
  options.home.apps.development.zed.enable =
    lib.mkEnableOption "Zed editor";

  config = lib.mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;
      # Binary installed via Homebrew cask (see pkgs/zed-editor); home-manager
      # only manages settings.json / keymaps / extensions in ~/.config/zed/.
      package = null;

      # Initial extensions — Zed auto-installs on first launch. Adding
      # extensions via the GUI later still works; they live in Zed's
      # writable data dir.
      extensions = [
        "nix"
        # "toml"
      ];

      # Declared keys are merged into ~/.config/zed/settings.json. Untouched
      # keys (anything not listed here) survive UI edits.
      # Reference: https://zed.dev/docs/configuring-zed
      userSettings = {
        vim_mode = true;
        format_on_save = "on";
        tab_size = 2;

        auto_update = false;

        vim = {
          toggle_relative_line_numbers = true;
        };

        which_key = {
          enabled = true;
        };

        session = {
          trust_all_worktrees = true;
        };

        agent_servers = {
          claude-acp = {
            type = "registry";
          };
        };

        theme = {
          mode = "system";
          light = "Tokyo Night Light";
          dark = "Tokyo Night Storm";
        };
      };

      # userKeymaps = [ ... ];
    };
  };
}
