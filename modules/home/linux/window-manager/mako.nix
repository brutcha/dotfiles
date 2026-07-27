{ config, lib, ... }:
#
# Mako (https://github.com/emersion/mako) — Wayland notification daemon.
#
# Available options:
# - home.apps.windowManager.mako.enable
#
let
  cfg = config.home.apps.windowManager.mako;
  c = config.theme.dark;
in
{
  options.home.apps.windowManager.mako.enable =
    lib.mkEnableOption "Mako notification daemon";

  config = lib.mkIf cfg.enable {
    services.mako = {
      enable = true;
      settings = {
        font = "JetBrainsMonoNL Nerd Font 10";
        background-color = c.bg;
        text-color = c.fg;
        border-color = c.blue;
        border-size = 2;
        border-radius = 6;
        default-timeout = 6000;
        anchor = "top-right";
        margin = "8";
        padding = "10";
        max-visible = 5;
      };
    };
  };
}
