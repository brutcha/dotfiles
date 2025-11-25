{ config, lib, pkgs, ... }:
#
# Cross-platform system-level applications
#
# Available options:
# - shared.apps.system.insync.enable        - Cloud storage sync
#
let
  cfg = config.shared.apps.system;
in
{
  options.shared.apps.system = {
    insync.enable = lib.mkEnableOption "Insync - Google Drive/Dropbox/OneDrive sync";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.insync.enable {
      nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "insync";
      environment.systemPackages = [ pkgs.insync ];
    })
  ];
}