{ config, lib, pkgs, ... }:
#
# Cross-platform development applications
#
# Available options:
# - shared.apps.development.postman.enable     - API development and testing (unfree)
# - shared.apps.development.docker.enable      - Docker containerization platform
# - shared.apps.development.antigravity.enable - Agentic IDE
# - shared.apps.development.emdash.enable      - Multi-agent dev environment (.dmg/AppImage)
#
let
  cfg = config.shared.apps.development;
in
{
  options.shared.apps.development = {
    postman.enable = lib.mkEnableOption "Postman - API development and testing";
    docker.enable = lib.mkEnableOption "Docker - containerization platform";
    antigravity.enable = lib.mkEnableOption "Antigravity - Agentic IDE";
    emdash.enable = lib.mkEnableOption "Emdash - multi-agent dev environment";
    zed-editor.enable = lib.mkEnableOption "Zed - editor (settings via home.apps.development.zed)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.postman.enable {
      nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "postman";
      environment.systemPackages = [ pkgs.postman ];
    })

    (lib.mkIf cfg.docker.enable {
      environment.systemPackages = [ pkgs.docker ];
    })

    (lib.mkIf cfg.antigravity.enable {
      # nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "postman";
      environment.systemPackages = [ pkgs.antigravity ];
    })

    (lib.mkIf cfg.emdash.enable {
      environment.systemPackages = [ pkgs.emdash ];
    })

    (lib.mkIf cfg.zed-editor.enable {
      environment.systemPackages = [ pkgs.zed-editor ];
    })
  ];
}
