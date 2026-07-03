{ config, lib, pkgs, ... }:
#
# macOS development applications
#
# Available options:
# - darwin.apps.development.docker-desktop.enable  - Docker Desktop with daemon
# - darwin.apps.development.orbstack.enable        - Lightweight Docker alternative
# - darwin.apps.development.android-studio.enable  - Android Studio (brew cask)
# - darwin.apps.development.android-tools.enable   - adb/fastboot CLI (auto-on with studio)
#
let
  cfg = config.darwin.apps.development;
in
{
  options.darwin.apps.development = {
    docker-desktop.enable = lib.mkEnableOption "Docker Desktop - Docker with GUI and daemon";
    orbstack.enable = lib.mkEnableOption "OrbStack - Fast, light Docker and Linux machines";
    android-studio.enable = lib.mkEnableOption "Android Studio - IDE + AVD manager (brew cask)";
    android-tools.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.android-studio.enable;
      description = "Install android-tools (adb, fastboot) on PATH. Auto-on with android-studio.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.docker-desktop.enable {
      nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "docker-desktop";
      environment.systemPackages = [ pkgs.docker-desktop ];
    })

    (lib.mkIf cfg.orbstack.enable {
      nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "orbstack";
      environment.systemPackages = [ pkgs.orbstack ];
    })

    (lib.mkIf cfg.android-studio.enable {
      environment.systemPackages = [ pkgs.android-studio ];
    })

    (lib.mkIf cfg.android-tools.enable {
      environment.systemPackages = [ pkgs.android-tools ];
    })
  ];
}
