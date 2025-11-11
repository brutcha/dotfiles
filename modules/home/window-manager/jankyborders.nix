{ config, utils, ... }:

# JankyBorders - customizable window borders for macOS
# https://github.com/FelixKratz/JankyBorders/wiki/Man-Page
# https://nix-community.github.io/home-manager/options.xhtml#opt-services.jankyborders.enable
{
  services.jankyborders = {
    enable = true;
    settings = {
      active_color = utils.colors.toARGB config.theme.dark.blue 1;
      inactive_color = utils.colors.toARGB config.theme.dark.blue 0;
      width = 8.0;
    };
  };
}
