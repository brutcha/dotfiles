{ config, lib, ... }:
#
# Fuzzel (https://codeberg.org/dnkl/fuzzel) — dmenu-like Wayland launcher.
#
# Available options:
# - home.apps.windowManager.fuzzel.enable
#
let
  cfg = config.home.apps.windowManager.fuzzel;
  terminal = config.home.apps.windowManager.terminal;
  c = config.theme.dark;
  # fuzzel wants rrggbbaa hex without the leading '#'.
  stripHash = s: lib.removePrefix "#" s;
in
{
  options.home.apps.windowManager.fuzzel.enable =
    lib.mkEnableOption "Fuzzel application launcher";

  config = lib.mkIf cfg.enable {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMonoNL Nerd Font:size=12";
          layer = "overlay";
          width = 40;
          lines = 15;
          horizontal-pad = 20;
          vertical-pad = 12;
          inner-pad = 8;
        } // lib.optionalAttrs (terminal != null) { inherit terminal; };
        colors = {
          background      = "${stripHash c.bg}f0";
          text            = "${stripHash c.fg}ff";
          match           = "${stripHash c.blue}ff";
          selection       = "${stripHash c.bg_highlight}ff";
          selection-text  = "${stripHash c.fg}ff";
          selection-match = "${stripHash c.blue}ff";
          border          = "${stripHash c.blue}ff";
        };
        border = {
          width = 2;
          radius = 0;
        };
      };
    };
  };
}
