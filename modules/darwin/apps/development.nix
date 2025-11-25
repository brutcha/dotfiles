{ config, lib, pkgs, ... }:
#
# macOS development applications
#
# Available options:
# - darwin.apps.development.docker-desktop.enable - Docker Desktop with daemon
# - darwin.apps.development.orbstack.enable - Lightweight Docker alternative
#
let
  cfg = config.darwin.apps.development;
in
{
  options.darwin.apps.development = {
    docker-desktop.enable = lib.mkEnableOption "Docker Desktop - Docker with GUI and daemon";
    orbstack.enable = lib.mkEnableOption "OrbStack - Fast, light Docker and Linux machines";
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
  ];
}
