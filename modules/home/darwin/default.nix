{ lib, pkgs, ... }:
#
# Darwin bundle — imports the shared modules + darwin-specific extras +
# LaunchServices registration. Non-darwin hosts import ./default.nix directly.
#
{
  imports = [
    ../default.nix     # shared: theme, fonts, shell, development
    ./development.nix  # darwin dev extras: lazydocker, xcbuild
    ./internet         # helium
    ./security         # keepass
    ./window-manager   # aerospace, sketchybar, jankyborders
  ];

  # home-manager symlinks Mac .app bundles under ~/Applications/Home Manager Apps/,
  # but LaunchServices doesn't recurse into that subdirectory. Re-register each
  # bundle's resolved nix-store target so `open -a`, Spotlight, and Launchpad
  # find them (`lsregister -f` needs a real path, not a symlink).
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
