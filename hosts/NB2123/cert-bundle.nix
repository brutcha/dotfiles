{ config, pkgs, private, ... }:
#
# Corporate CA merged into /etc/nix/cert-bundle.pem at every activation.
# PEM content comes from private.nix at eval time.
#
let
  corpCa = pkgs.writeText "corp-ca.pem" private.secrets.corpCaBundlePem;
in
{
  system.activationScripts.extraActivation.text = ''
    set -eu
    mkdir -p /etc/nix
    cat /etc/ssl/cert.pem ${corpCa} > /etc/nix/cert-bundle.pem
    chmod 0644 /etc/nix/cert-bundle.pem
  '';

  nix.settings = {
    trusted-users = [ "root" config.system.primaryUser ];
    ssl-cert-file = "/etc/nix/cert-bundle.pem";
  };
}
