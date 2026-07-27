{ config, lib, ... }:
#
# astoria — sops-nix (https://github.com/Mic92/sops-nix) secret declarations.
#
# `neededForUsers = true` materializes the hashed-password secret into
# /run/secrets-for-users BEFORE useradd runs. Without it, the user gets
# created with a locked shadow entry — silent soft-lock, recovery via
# installer USB only.
#
# The assertion below guards against enabling systemd-sysusers or userborn:
# on those paths sops-install-secrets-for-users' Before= ordering is soft,
# and a decrypt failure would let sysusers create the user with a `!`
# shadow entry (same soft-lock shape).
#
{
  assertions = [
    {
      assertion = !(config.systemd.sysusers.enable or false)
              && !((config.services.userborn or {}).enable or false);
      message = ''
        astoria: systemd.sysusers.enable and services.userborn.enable must both
        stay false while users.mutableUsers = false and hashedPasswordFile is
        sops-managed — the systemd-sysusers/userborn path uses soft ordering
        that silently soft-locks the user on decrypt failure. See secrets.nix.
      '';
    }
  ];

  sops = {
    defaultSopsFile = ./secrets/astoria.yaml;
    # age.sshKeyPaths defaults to services.openssh.hostKeys filtered to
    # ed25519 (see sops-nix modules/sops/default.nix); openssh is enabled
    # at the system level so no explicit setting needed.

    secrets = {
      "users/brutcha/hashed-password" = {
        neededForUsers = true;
      };
      "restic/repo-password" = { };
      "rclone/webdav.conf" = { };
      # tailscale/authkey — add when mesh VPN goes in (plan §7). Declared
      # here would require the yaml key to exist too, else sops-install-secrets
      # aborts activation.
    };
  };
}
