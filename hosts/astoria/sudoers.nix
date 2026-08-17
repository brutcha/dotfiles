{ lib, pkgs, ... }:
# NOPASSWD for exact commands only. The `.#astoria` rule still trusts whatever
# flake sits in the caller's cwd — accepted convenience; don't extend the pattern.
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "tlp-profile-switch" ''
      set -euo pipefail

      case "''${1-}" in
        performance|balanced|power-saver)
          exec ${pkgs.tlp}/bin/tlp "$1"
          ;;
        *)
          echo "Usage: tlp-profile-switch {performance|balanced|power-saver}" >&2
          exit 1
          ;;
      esac
    '')
  ];

  security.sudo.extraConfig = lib.mkAfter ''
    brutcha ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild switch --flake .\#astoria
    brutcha ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild switch --flake /etc/nixos\#astoria
    brutcha ALL=(root) NOPASSWD: /run/current-system/sw/bin/tlp-profile-switch performance
    brutcha ALL=(root) NOPASSWD: /run/current-system/sw/bin/tlp-profile-switch balanced
    brutcha ALL=(root) NOPASSWD: /run/current-system/sw/bin/tlp-profile-switch power-saver
  '';
}
