{ config, pkgs, ... }:
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

    if [ ! -f "$vault" ]; then
      echo "warn: $vault missing — /etc/nix/cert-bundle.pem not updated" >&2
    elif launchctl asuser "${uid}" sudo -u "${user}" \
           ${extractCa} "${user}" "$vault" "$tmp" >/dev/null 2>&1; then
      mkdir -p /etc/nix
      cat /etc/ssl/cert.pem "$tmp" > /etc/nix/cert-bundle.pem
      chmod 0644 /etc/nix/cert-bundle.pem
      echo "corp CA: extracted from KDBX, merged into /etc/nix/cert-bundle.pem" >&2
    else
      echo "warn: could not extract corp/ca-bundle from KDBX — /etc/nix/cert-bundle.pem not updated" >&2
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
