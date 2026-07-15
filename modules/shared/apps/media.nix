{ config, lib, pkgs, ... }:
#
# Cross-platform media applications
#
# Available options:
# - shared.apps.media.obs-studio.enable - OBS Studio (screen recorder / streamer / virtual camera)
#
# Auto-enables when the home-manager option `home.apps.media.obs.enable` is
# set for the primary user, so a single toggle in home.nix installs the cask
# and pins the config.
#
let
  cfg = config.shared.apps.media;

  homeObsEnabled =
    (config.home-manager.users.${config.system.primaryUser}.home.apps.media.obs.enable or false);
in
{
  options.shared.apps.media = {
    obs-studio.enable = lib.mkEnableOption "OBS Studio - screen recording, streaming, virtual camera";
  };

  config = lib.mkIf (cfg.obs-studio.enable || homeObsEnabled) {
    environment.systemPackages = [ pkgs.obs-studio ];
  };
}
