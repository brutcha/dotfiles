{ lib, pkgs, ... }:
#
# Darwin bundle — darwin-only categories. Shared modules
# (theme/fonts/shell/development) come from the universal bundle in
# ../default.nix; don't re-import from here — the cycle overflows the
# stack before `filterModules`'s dedup runs.
#
{
  imports = [
    ./development.nix
    ./internet
    ./media
    ./security
    ./window-manager
  ];

  # LaunchServices doesn't recurse into ~/Applications/Home Manager Apps/;
  # re-register each .app's real nix-store target so `open -a`, Spotlight,
  # Launchpad find them.
  home.activation.registerNixApps =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
      (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
        for app in "$HOME/Applications/Home Manager Apps/"*.app; do
          [ -L "$app" ] || continue
          $DRY_RUN_CMD "$lsregister" -f "$(readlink "$app")"
        done
      '');
}
