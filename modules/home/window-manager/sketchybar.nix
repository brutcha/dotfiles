{ pkgs, config, utils, ... }:

# SketchyBar: status bar replacement integrated with AeroSpace
# Lua-based configuration using SbarLua module
# Tokyo Night theme
#
# https://felixkratz.github.io/SketchyBar/setup
# https://nix-community.github.io/home-manager/options.xhtml#opt-programs.sketchybar.enable

{
  programs = {
    sketchybar = {
      enable = true;
      config = {
        source = ../../../config/sketchybar;
        recursive = true;
      };
      configType = "lua";
      extraPackages = with pkgs; [
        lua5_4
        sbarlua
        aerospace
        bottom
      ];
    };
  };

  xdg.configFile = {
    # Override sketchybarrc to ensure it's executable
    # (programs.sketchybar.config.source copies files but doesn't preserve +x)
    "sketchybar/sketchybarrc" = {
      source = ../../../config/sketchybar/sketchybarrc;
      executable = true;
    };

    # Generate colors.lua dynamically from theme.nix to ensure consistency
    "sketchybar/colors.lua".text =
      let
        c = config.theme.dark;
        toARGB = utils.colors.toARGB;
      in
      ''
        #!/usr/bin/env lua

        -- SketchyBar Color Configuration
        -- Tokyo Night theme colors - Generated from theme.nix
        -- This file is auto-generated to stay in sync with Neovim theme

        local M = {}

        -- Base colors
        M.black          = "${toARGB c.black 1.0}"
        M.white          = "${toARGB "#ffffff" 1.0}"
        M.bg_dark        = "${toARGB c.bg_dark 1.0}"
        M.bg             = "${toARGB c.bg 1.0}"
        M.bg_highlight   = "${toARGB c.bg_highlight 1.0}"
        M.fg             = "${toARGB c.fg 1.0}"
        M.comment        = "${toARGB c.comment 1.0}"

        -- Accent colors
        M.blue           = "${toARGB c.blue 1.0}"
        M.cyan           = "${toARGB c.cyan 1.0}"
        M.magenta        = "${toARGB c.magenta 1.0}"
        M.purple         = "${toARGB c.purple 1.0}"
        M.orange         = "${toARGB c.orange 1.0}"
        M.yellow         = "${toARGB c.yellow 1.0}"
        M.green          = "${toARGB c.green 1.0}"
        M.red            = "${toARGB c.red 1.0}"

        -- Transparency
        M.transparent    = "0x00000000"

        -- Workspace indicator colors (for aerospace integration)
        M.workspace_active_bg    = M.purple
        M.workspace_active_fg    = M.black
        M.workspace_visible_bg   = "${toARGB c.purple 0.6}"
        M.workspace_visible_fg   = M.black
        M.workspace_inactive_bg  = "${toARGB c.blue 0.2}"
        M.workspace_inactive_fg  = "${toARGB "#ffffff" 0.53}"
        M.workspace_default_bg   = "${toARGB c.blue 0.27}"

        -- Bar appearance
        M.bar_bg         = M.bg_dark
        M.bar_border     = M.transparent

        -- Default item colors
        M.icon           = M.fg
        M.icon_primary   = "${toARGB "#ffffff" 0.8}"
        M.label          = M.fg
        M.label_primary   = "${toARGB "#ffffff" 0.8}"
        M.popup_bg       = M.bg_highlight
        M.popup_border   = M.blue

        -- Taskbar
        M.taskbar_divider = M.comment

        return M
      '';
  };
}
