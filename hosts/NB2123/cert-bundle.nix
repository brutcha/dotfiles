{ config, lib, pkgs, private ? {}, ... }:
#
# Corp CA merged into /etc/nix/cert-bundle.pem at system activation.
# Extraction happens as the primary user via `launchctl asuser + sudo -u` so
# du234's Keychain is reachable; the merge then runs as root. Single-rebuild
# bootstrap — no reliance on home-manager writing an intermediate PEM.
#
let
  keepassxcCli = pkgs.keepassxc.passthru.cli;

  user = config.system.primaryUser;
  uid = "$(id -u ${user})";

  corpCaSearch = private.corpCaKeychainSearch or null;

  # Runs as the primary user, in that user's launchd/keychain session context.
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
    vault="/Users/${user}/.config/dotfiles/vault.kdbx"
    tmp="$(mktemp)"
    chown "${user}" "$tmp"
    chmod 0600 "$tmp"

    # Base bundle first so consumers have a valid file even if appends fail.
    mkdir -p /etc/nix
    cat /etc/ssl/cert.pem > /etc/nix/cert-bundle.pem
    chmod 0644 /etc/nix/cert-bundle.pem

    ${lib.optionalString (corpCaSearch != null) ''
      keychainTmp="$(mktemp)"
      chown "${user}" "$keychainTmp"
      chmod 0600 "$keychainTmp"
      if /usr/bin/security find-certificate -a -c ${lib.escapeShellArg corpCaSearch} \
           -p /Library/Keychains/System.keychain > "$keychainTmp" 2>/dev/null \
           && [ -s "$keychainTmp" ]; then
        cat "$keychainTmp" >> /etc/nix/cert-bundle.pem
        echo "corp CA: appended '${corpCaSearch}' match from System keychain" >&2
      else
        echo "warn: no cert matched '${corpCaSearch}' in System keychain — bundle will lack it" >&2
      fi
      rm -f "$keychainTmp"
    ''}

    if [ ! -f "$vault" ]; then
      echo "warn: $vault missing — KDBX certs not appended to /etc/nix/cert-bundle.pem" >&2
    elif launchctl asuser "${uid}" sudo -u "${user}" \
           ${extractCa} "${user}" "$vault" "$tmp" >/dev/null 2>&1; then
      cat "$tmp" >> /etc/nix/cert-bundle.pem
      echo "corp CA: extracted from KDBX, merged into /etc/nix/cert-bundle.pem" >&2
    else
      echo "warn: could not extract corp/ca-bundle from KDBX — KDBX certs not appended" >&2
    fi

    rm -f "$tmp"
  '';

  # Runs after user (home-manager) activation, so the podman package is
  # available. Injects the corp CA into the podman machine VM's trust store.
  # Every branch logs so a skipped inject is diagnosable — otherwise a fresh
  # setup (VM not yet started on first login) looks identical to a success.
  system.activationScripts.postActivation.text = ''
    if [ ! -f /etc/nix/cert-bundle.pem ]; then
      echo "note: /etc/nix/cert-bundle.pem missing — skipping podman VM CA-inject" >&2
    elif ! launchctl asuser "${uid}" sudo -Hu "${user}" \
           ${pkgs.podman}/bin/podman machine ssh true >/dev/null 2>&1; then
      echo "note: podman machine not reachable — skipping VM CA-inject (re-runs on next darwin-rebuild once VM is up)" >&2
    elif launchctl asuser "${uid}" sudo -Hu "${user}" \
           ${pkgs.podman}/bin/podman machine ssh \
             'sudo tee /etc/pki/ca-trust/source/anchors/corp-ca.crt >/dev/null && sudo update-ca-trust' \
           < /etc/nix/cert-bundle.pem >/dev/null 2>&1; then
      echo "corp CA: injected into podman machine VM" >&2
    else
      echo "warn: podman machine ssh CA-inject failed" >&2
    fi
  '';

  nix.settings = {
    trusted-users = [ "root" config.system.primaryUser ];
    ssl-cert-file = "/etc/nix/cert-bundle.pem";
  };
}
