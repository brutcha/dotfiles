{ config, osConfig, lib, pkgs, ... }:
#
# macOS-only development extras
#
# Available options:
# - home.apps.development.lazydocker.enable - TUI for Docker; auto-on when
#   shared.apps.development.docker or darwin.apps.development.orbstack is enabled
# - home.apps.development.xcbuild.enable    - xcrun shim, default true on darwin
#
let
  cfg = config.home.apps.development;
in
{
  # ./default.nix is imported by modules/home/default.nix — don't re-import here.

  options.home.apps.development = {
    lazydocker.enable = lib.mkOption {
      type = lib.types.bool;
      default =
        (osConfig.shared.apps.development.docker.enable or false)
        || (osConfig.darwin.apps.development.orbstack.enable or false);
      description = "Install lazydocker. Auto-enables when docker/orbstack is on.";
    };
    xcbuild.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.home.apps.development.direnv.enable;
      description = "xcbuild — nix `xcrun` shim. Auto-enables with direnv (dev-shells usually need native builds).";
    };
  };

  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkMerge [
    (lib.mkIf cfg.lazydocker.enable {
      programs.lazydocker.enable = true;
    })

    (lib.mkIf cfg.xcbuild.enable {
      home.packages = [ pkgs.xcbuild ];
    })
  ]);
}
