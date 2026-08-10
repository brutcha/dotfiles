{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
#
# Native Wayland/StatusNotifierItem system tray for the official Spotify
# Linux client — not in nixpkgs. Unlike the old X11-only `spotify-tray`
# package, its SNI implementation registers correctly with waybar's `tray`
# module.
#
# CAVEAT: its click-to-hide/show window management (hyprland.go,
# hyprland_advanced.go, hyprland_bench.go, hyprland_fast.go) talks to
# Hyprland's IPC socket directly and does nothing on Sway/wlroots — only the
# tray icon + its MPRIS-driven play/pause/skip menu work here. Window
# hide/show on Sway is handled separately via a scratchpad keybind.
#
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

  vendorHash = "sha256-2o+mtkOS+69kB9SyTIotTxr0b9UVhkefHfw7vPHIbr0=";

  meta = {
    description = "Native Wayland (StatusNotifierItem) system tray for the official Spotify Linux client";
    homepage = "https://github.com/xander1421/spotify-tray-wayland";
    license = lib.licenses.mit;
    mainProgram = "spotify-tray-wayland";
    platforms = lib.platforms.linux;
  };
})
