#
# Makima home-manager configuration (user-level)
#
# This configuration is applied to the user specified in hosts/makima/default.nix
# System-level configuration is in ./default.nix
#
{ private, ... }:
{
  # State version - should match the Home Manager version you first installed
  # Do not change this after initial setup unless you read the release notes
  # https://nix-community.github.io/home-manager/index.xhtml#sec-install-nix-darwin-module
  home.stateVersion = "25.05";

  # https://nix-community.github.io/home-manager/
  imports = [ ../../modules/home/darwin ];

  home.apps = {
    development = {
      ghostty.enable = true;
      git.enable = true;
      claude-code.enable = true;
    };

    internet = {
      helium.enable = true;
      davmail.enable = true; # CalDAV/CardDAV/LDAP bridge for the corp account below
    };
  };

  # Work Exchange/O365 account — the org blocks native Outlook on macOS.
  # Mail talks EWS directly (Thunderbird native, OAuth2 + MFA popup);
  # calendar/contacts/GAL have no native EWS support and go through DavMail.
  # The account has two identities: `private.user.email` is the mailbox
  # address (From:), `private.user.login` the Microsoft sign-in UPN.
  programs.thunderbird = {
    enable = true;
    profiles.corp = {
      isDefault = true;
      # GAL via DavMail's LDAP gateway — raw prefs, accounts.contact has no
      # ldap remote type.
      settings = {
        "ldap_2.servers.corpGal.description" = "Global Address List";
        "ldap_2.servers.corpGal.uri" = "ldap://localhost:1389/ou=people??sub";
        "ldap_2.servers.corpGal.maxHits" = 100;
        "ldap_2.autoComplete.useDirectory" = true;
        "ldap_2.autoComplete.directoryServer" = "ldap_2.servers.corpGal";
      };
    };
  };

  accounts.email.accounts.corp = {
    primary = true;
    address = private.user.email;
    userName = private.user.login;
    realName = private.user.name;
    flavor = "outlook.office365.com-ews";
    thunderbird.enable = true;
    thunderbird.profiles = [ "corp" ];
  };

  accounts.calendar.accounts.corp-calendar = {
    primary = true;
    remote = {
      type = "caldav";
      url = "http://localhost:1080/users/${private.user.email}/calendar/";
      userName = private.user.login;
    };
    thunderbird.enable = true;
    thunderbird.profiles = [ "corp" ];
  };

  accounts.contact.accounts.corp-contacts = {
    remote = {
      type = "carddav";
      url = "http://localhost:1080/users/${private.user.email}/contacts/";
      userName = private.user.login;
    };
    thunderbird.enable = true;
    thunderbird.profiles = [ "corp" ];
  };
}
