{ ... }:
#
# Linux bundle — linux-only categories. Shared modules come via the
# universal bundle (see darwin/default.nix note on the removed back-ref).
#
{
  imports = [
    ./internet
    ./media
    ./thunar.nix
    ./window-manager
  ];
}
