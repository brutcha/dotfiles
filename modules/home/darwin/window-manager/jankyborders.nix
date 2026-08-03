{ config, lib, pkgs, helpers, ... }:
#
# JankyBorders — window borders (https://github.com/FelixKratz/JankyBorders)
#
# Available options:
# - home.apps.windowManager.jankyborders.enable
#
let
  cfg = config.home.apps.windowManager.jankyborders;
in
{
  options.home.apps.windowManager.jankyborders.enable =
    lib.mkEnableOption "JankyBorders window border highlight";

  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    services.jankyborders = {
      enable = true;
      settings = {
        active_color = helpers.colors.toARGB config.theme.dark.blue 1;
        inactive_color = helpers.colors.toARGB config.theme.dark.blue 0;
        width = 8.0;
      };
    };
  };
}
