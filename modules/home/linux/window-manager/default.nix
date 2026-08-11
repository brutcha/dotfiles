#
# Linux window manager stack: Sway + Waybar + Mako + Fuzzel + Swaylock.
#
{ lib, ... }:
{
  imports = [
    ./sway.nix
    ./waybar.nix
    ./mako.nix
    ./fuzzel.nix
    ./swaylock.nix
    ./screenshot.nix
  ];

  # Host-set (see hosts/astoria/home.nix); consumers omit their binding when null.
  options.home.apps.windowManager = {
    terminal = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Command to launch as the terminal application.";
    };
    menu = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Command to launch as the application launcher.";
    };
  };
}
