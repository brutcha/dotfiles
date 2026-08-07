{ lib, ... }:
# NOPASSWD for these two exact rebuild commands only — no wildcard, so a
# passwordless call can't smuggle in an arbitrary --flake path.
{
  security.sudo.extraConfig = lib.mkAfter ''
    brutcha ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild switch --flake .\#astoria
    brutcha ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild switch --flake /etc/nixos\#astoria
  '';
}
