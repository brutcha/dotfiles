{ lib, hostSystem, ... }:
#
# Universal home-manager bundle. Every host imports via
# `imports = [ ../../modules/home ];`; the bundle self-selects the platform
# sub-bundle based on `hostSystem` (threaded from flake.nix extraSpecialArgs).
#
# `hostSystem` (not `pkgs.stdenv.hostPlatform.*`) because the imports list
# must not depend on `pkgs` — HM resolves pkgs via `_module.args` → `config`,
# so touching it during imports triggers infinite recursion.
#
{
  imports = [
    ./theme.nix
    ./fonts.nix
    ./shell.nix
    ./development
  ]
  ++ lib.optionals (lib.hasSuffix "-darwin" hostSystem) [ ./darwin ]
  ++ lib.optionals (lib.hasSuffix "-linux"  hostSystem) [ ./linux ];
}
