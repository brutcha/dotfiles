{ config, lib, pkgs, ... }:
#
# LibreWolf (https://librewolf.net) — hardened Firefox fork.
#
# Available options:
# - home.apps.internet.librewolf.enable
#
# `enhanced-h264ify` blocks AV1 on YouTube (Ice Lake has no HW AV1 decode)
# while leaving VP9 — which the Gen 11 media block DOES decode — available.
# Plain `h264ify` caps 4K/1440p (YouTube stopped H.264 encoding at those
# resolutions).
#
# extensions.packages symlinks profiles but does not enable them; the
# `autoDisableScopes = 0` pref is the standard HM idiom to auto-enable
# declaratively-installed extensions on first launch.
#
# NUR overlay wired at the system level (see hosts/astoria/default.nix).
#
let
  cfg = config.home.apps.internet.librewolf;
in
{
  options.home.apps.internet.librewolf.enable =
    lib.mkEnableOption "LibreWolf with enhanced-h264ify + nextcloud-passwords";

  config = lib.mkIf cfg.enable {
    programs.librewolf = {
      enable = true;
      profiles.default = {
        settings."extensions.autoDisableScopes" = 0;
        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          enhanced-h264ify
          nextcloud-passwords
        ];
      };
    };
  };
}
