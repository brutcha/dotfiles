{ config, pkgs, ... }:
#
# Corp CA merged into /etc/nix/cert-bundle.pem at system activation.
# Extraction happens as the primary user via `launchctl asuser + sudo -u` so
# du234's Keychain is reachable; the merge then runs as root. Single-rebuild
# bootstrap — no reliance on home-manager writing an intermediate PEM.
#
let
  keepassxcCli = pkgs.keepassxc.passthru.cli;

  # Runs as the primary user, in that user's launchd/keychain session context.
  # Args: <user> <vault-path> <output-path>
  # Keychain path passed explicitly because HOME is inherited from the root
  # activate script (~root), which makes `security` search the wrong keychain.
  extractCa = pkgs.writeShellScript "extract-corp-ca" ''
    set -e
    user="$1"
    vault="$2"
    output="$3"
    keychain="/Users/$user/Library/Keychains/login.keychain-db"
    master="$(/usr/bin/security find-generic-password -a "$user" -s kdbx-master -w "$keychain")"
    ${keepassxcCli} attachment-export "$vault" corp/ca-bundle ca.pem "$output" <<< "$master" >/dev/null 2>&1
  '';
in
{
  system.activationScripts.extraActivation.text = ''
    user="${config.system.primaryUser}"
    vault="/Users/$user/.config/dotfiles/vault.kdbx"
    tmp="$(mktemp)"
    chown "$user" "$tmp"
    chmod 0600 "$tmp"

    if [ ! -f "$vault" ]; then
      echo "warn: $vault missing — /etc/nix/cert-bundle.pem not updated" >&2
    elif launchctl asuser "$(id -u "$user")" sudo -u "$user" \
           ${extractCa} "$user" "$vault" "$tmp" >/dev/null 2>&1; then
      mkdir -p /etc/nix
      cat /etc/ssl/cert.pem "$tmp" > /etc/nix/cert-bundle.pem
      chmod 0644 /etc/nix/cert-bundle.pem
      echo "corp CA: extracted from KDBX, merged into /etc/nix/cert-bundle.pem" >&2
    else
      echo "warn: could not extract corp/ca-bundle from KDBX — /etc/nix/cert-bundle.pem not updated" >&2
    fi

    rm -f "$tmp"
  '';

  nix.settings = {
    trusted-users = [ "root" config.system.primaryUser ];
    ssl-cert-file = "/etc/nix/cert-bundle.pem";
  };
}
