#
# Linux window manager stack: Sway + Waybar + Mako + Fuzzel + Swaylock.
#
{
  imports = [
    ./sway.nix
    ./waybar.nix
    ./mako.nix
    ./fuzzel.nix
    ./swaylock.nix
    ./screenshot.nix
  ];
}
