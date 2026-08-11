{
  lib,
  buildGoModule,
  fetchFromGitHub,
  spotify,
  # "hyprland" (upstream default) or "sway" — see postPatch.
  windowManager ? "hyprland",
}:
#
# Native Wayland/StatusNotifierItem system tray for the official Spotify
# Linux client — not in nixpkgs. Unlike the old X11-only `spotify-tray`
# package, its SNI implementation registers correctly with waybar's `tray`
# module.
#
assert lib.assertMsg (builtins.elem windowManager [ "hyprland" "sway" ])
  "spotify-tray-wayland: windowManager must be \"hyprland\" or \"sway\", got ${windowManager}";
buildGoModule (finalAttrs: {
  pname = "spotify-tray-wayland";
  version = "1.1.3";

  src = fetchFromGitHub {
    owner = "xander1421";
    repo = "spotify-tray-wayland";
    rev = "v${finalAttrs.version}";
    hash = "sha256-wektRV300nIXEjreSWjgAiXWA+s4usPAnIX+fyzCicA=";
  };

  # Go module lives in a nested subdirectory of the same name.
  modRoot = "spotify-tray-wayland";

  # Upstream's icon lookup hardcodes FHS paths + the wrong filename, so it
  # never finds an icon on NixOS — point it at nixpkgs' spotify package.
  # sway.go swap-in below is conditional on windowManager (see arg above);
  # upstream's Hyprland IPC backend does nothing on Sway/wlroots.
  postPatch = ''
    substituteInPlace spotify-tray-wayland/main.go \
      --replace-fail 'iconPaths := []string{' \
        'iconPaths := []string{
      "${spotify}/share/icons/hicolor/256x256/apps/spotify-client.png",
      "${spotify}/share/icons/hicolor/128x128/apps/spotify-client.png",
      "${spotify}/share/icons/hicolor/64x64/apps/spotify-client.png",'
  '' + lib.optionalString (windowManager == "sway") ''
    cp ${./sway.go} spotify-tray-wayland/sway.go

    substituteInPlace spotify-tray-wayland/main.go \
      --replace-fail 'NewHyprlandManager()' 'NewSwayManager()'
  '';

  vendorHash = "sha256-2o+mtkOS+69kB9SyTIotTxr0b9UVhkefHfw7vPHIbr0=";

  meta = {
    description = "Native Wayland (StatusNotifierItem) system tray for the official Spotify Linux client"
      + lib.optionalString (windowManager == "sway") " (Sway backend)";
    homepage = "https://github.com/xander1421/spotify-tray-wayland";
    license = lib.licenses.gpl3Only;
    mainProgram = "spotify-tray-wayland";
    platforms = lib.platforms.linux;
  };
})
