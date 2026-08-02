{ config, lib, pkgs, ... }:
#
# imv (https://sr.ht/~exec64/imv/) — lightweight Wayland-native image viewer.
#
# Available options:
# - home.apps.media.imv.enable
#
let
  cfg = config.home.apps.media.imv;
in
{
  options.home.apps.media.imv.enable =
    lib.mkEnableOption "imv image viewer";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.imv ];

    xdg.mimeApps.enable = true;
    xdg.mimeApps.defaultApplications = {
      "image/png" = [ "imv.desktop" ];
      "image/jpeg" = [ "imv.desktop" ];
      "image/gif" = [ "imv.desktop" ];
      "image/webp" = [ "imv.desktop" ];
      "image/bmp" = [ "imv.desktop" ];
      "image/tiff" = [ "imv.desktop" ];
    };
  };
}
