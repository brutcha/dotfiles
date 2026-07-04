{ config, lib, pkgs, ... }:
#
# DavMail — local Exchange/O365 gateway (https://davmail.sourceforge.net)
#
# Available options:
# - home.apps.internet.davmail.enable   - run DavMail as a launchd agent
# - home.apps.internet.davmail.settings - davmail.properties overrides, merged over the defaults below
#
# Bridges Exchange Online to open protocols on localhost so any mail client
# can consume them: CalDAV + CardDAV on 1080, global-address-list LDAP on
# 1389. No password is ever stored — auth is OAuth2 device code (headless
# server mode can't open a browser): on first client connect the log prints
# a https://microsoft.com/devicelogin URL + code, complete it once (MFA) and
# the refresh token persists to the token file.
#
# Mode is O365EWS, not O365Graph: upstream's own release notes still call
# the Graph backend not production-ready as of 6.8.0. Revisit before
# Microsoft's phased EWS retirement (Oct 2026 → full Apr 2027).
#
let
  cfg = config.home.apps.internet.davmail;

  # `generate` writes values as-is (bool/int -> string coercion only happens
  # when routed through a module option of this format's type), so stringify
  # here rather than passing raw Nix booleans/ints straight to jq.
  toPropertyValue = v: if builtins.isBool v then lib.boolToString v else toString v;

  # Keys must stay quoted/flat — javaProperties rejects nested attrsets,
  # which is what an unquoted `davmail.server = true` would produce.
  propertiesFile = (pkgs.formats.javaProperties { }).generate "davmail.properties" (
    lib.mapAttrs (_: toPropertyValue) ({
      "davmail.server" = true;
      "davmail.mode" = "O365EWS";
      "davmail.url" = "https://outlook.office365.com/EWS/Exchange.asmx";
      "davmail.authentication" = "O365DeviceCode";
      "davmail.allowRemote" = false;
      "davmail.caldavPort" = 1080; # serves both CalDAV and CardDAV
      "davmail.ldapPort" = 1389; # global address list
      # Refresh token can't persist into the properties file itself (read-only
      # store symlink) — point it at a separate writable file instead.
      "davmail.oauth.tokenFilePath" = "${config.home.homeDirectory}/.config/davmail/oauth-tokens";
      "davmail.logFilePath" = "${config.home.homeDirectory}/Library/Logs/davmail.log";
    } // cfg.settings)
  );
in
{
  options.home.apps.internet.davmail = {
    enable = lib.mkEnableOption "DavMail Exchange gateway (CalDAV/CardDAV/LDAP on localhost)";

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.bool lib.types.int lib.types.str ]);
      default = { };
      example = { "davmail.authentication" = "O365Interactive"; };
      description = "davmail.properties overrides, merged over the module defaults.";
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    home.packages = [ pkgs.davmail ];

    home.file.".config/davmail/davmail.properties".source = propertiesFile;

    launchd.agents.davmail = {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.davmail}/bin/davmail"
          "${config.home.homeDirectory}/.config/davmail/davmail.properties"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/davmail-stdout.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/davmail-stderr.log";
      };
    };
  };
}
