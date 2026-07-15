{ config, lib, pkgs, ... }:
#
# Cross-platform security applications
#
# Available options:
# - shared.apps.security.keepassxc.enable - KeePassXC password manager
#
# Auto-enables when the home-manager option `home.apps.security.keepass.enable`
# is set for the primary user, so one toggle in home.nix installs the cask and
# wires the browser integration.
#
let
  cfg = config.shared.apps.security;

  homeKeepassEnabled =
    (config.home-manager.users.${config.system.primaryUser}.home.apps.security.keepass.enable or false);
in
{
  options.shared.apps.security = {
    keepassxc.enable = lib.mkEnableOption "KeePassXC password manager";
  };

  config = lib.mkIf (cfg.keepassxc.enable || homeKeepassEnabled) {
    environment.systemPackages = [ pkgs.keepassxc ];
  };
}
