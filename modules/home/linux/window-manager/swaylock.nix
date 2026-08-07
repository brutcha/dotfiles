{ config, lib, ... }:
#
# Swaylock (https://github.com/swaywm/swaylock) — Sway screen locker.
#
# Available options:
# - home.apps.windowManager.swaylock.enable
#
# Invoked by swayidle timeout chain (see sway.nix) and Mod+Escape.
#
let
  cfg = config.home.apps.windowManager.swaylock;
  c = config.theme.dark;
  # swaylock reads rrggbb hex, no leading '#'.
  stripHash = s: lib.removePrefix "#" s;
in
{
  options.home.apps.windowManager.swaylock.enable =
    lib.mkEnableOption "Swaylock screen locker";

  config = lib.mkIf cfg.enable {
    programs.swaylock = {
      enable = true;
      settings = {
        color = stripHash c.bg;
        font = "JetBrainsMonoNL Nerd Font";
        font-size = 24;

        indicator-radius = 100;
        indicator-thickness = 10;

        ring-color        = stripHash c.bg_dark;
        ring-clear-color  = stripHash c.orange;
        ring-caps-lock-color = stripHash c.yellow;
        ring-ver-color    = stripHash c.blue;
        ring-wrong-color  = stripHash c.red;

        key-hl-color   = stripHash c.blue;
        bs-hl-color    = stripHash c.red;
        text-color     = stripHash c.fg;
        text-clear-color = stripHash c.orange;
        text-ver-color = stripHash c.blue;
        text-wrong-color = stripHash c.red;
        text-caps-lock-color = stripHash c.yellow;

        inside-color        = stripHash c.bg;
        inside-clear-color  = stripHash c.bg;
        inside-ver-color    = stripHash c.bg;
        inside-wrong-color  = stripHash c.bg;
        inside-caps-lock-color = stripHash c.bg;

        line-color = stripHash c.bg;

        show-failed-attempts = true;
        daemonize = true;
        ignore-empty-password = true;
      };
    };
  };
}
