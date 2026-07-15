{ config, lib, pkgs, ... }:
#
# OBS Studio declarative config
#
# Available options:
# - home.apps.media.obs.enable - Symlink scene collection + profile from nix store
#
# Files are pinned as read-only symlinks; OBS can't persist scene edits back to
# these paths — change the nix files and rebuild instead. UI state (window
# geometry, dock layout in user.ini) stays writable.
#
# The scene collection encodes a Cam Link 4K source with a Crop/Pad + Sharpen
# filter chain, wired to the OBS Virtual Camera. Device UID (`0x1230000fd90067`)
# and canvas size (1782×1004) live in the JSON/INI files.
#
let
  cfg = config.home.apps.media.obs;

  # Match the scene-collection / profile filenames referenced from user.ini.
  # OBS looks up the active collection by the `SceneCollectionFile` key —
  # user.ini's [Basic] section must have Profile=/SceneCollection=<this>.
  collectionName = "Camlink";
  profileName = "Camlink";

  obsRoot = "Library/Application Support/obs-studio";
in
{
  options.home.apps.media.obs.enable =
    lib.mkEnableOption "OBS Studio declarative scene + profile";

  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    # force=true: symlinks live in nix store, no user content to preserve,
    # skip home-manager's .backup dance on every content update.
    home.file."${obsRoot}/basic/scenes/${collectionName}.json" = {
      source = ./obs/scene-collection.json;
      force = true;
    };

    home.file."${obsRoot}/basic/profiles/${profileName}/basic.ini" = {
      source = ./obs/basic.ini;
      force = true;
    };
  };
}
