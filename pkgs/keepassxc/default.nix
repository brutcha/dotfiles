{ helpers }:
#
# KeePassXC — https://keepassxc.org
#
# Homebrew cask on darwin — sidesteps the qtmacextras cctools ld SIGTRAP
# that hits when unstable HEAD drifts past the last cached build.
#
# Exposes CLI + proxy paths via passthru so callers don't repeat the
# /Applications/... prefix. Reference as `pkgs.keepassxc.passthru.cli`.
#
let
  marker = helpers.darwin.mkBrewCask { caskName = "keepassxc"; };
  appMacOS = "/Applications/KeePassXC.app/Contents/MacOS";
in
marker // {
  passthru = marker.passthru // {
    cli = "${appMacOS}/keepassxc-cli";
    proxy = "${appMacOS}/keepassxc-proxy";
  };
}
