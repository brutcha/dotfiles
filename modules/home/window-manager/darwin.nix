# macOS window manager configuration
#
# This module configures:
# - AeroSpace: tiling window manager for macOS
# - JankyBorders: customizable window borders
# - SketchyBar: status bar replacement integrated with AeroSpace
#
{
  imports = [
    ./aerospace.nix
    ./jankyborders.nix
    ./sketchybar.nix
  ];
}
