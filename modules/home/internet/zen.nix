{ inputs, pkgs, ... }:
{
  imports = [ inputs.zen-browser.homeModules.twilight ];

  programs.zen-browser = {
    enable = true;

    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      DisablePocket = true;
      DisableFeedbackCommands = true;
      DisableFirefoxStudies = true;
      
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };

      SanitizeOnShutdown = {
        FormData = true;
        Cache = true;
      };

      ExtensionSettings = {
        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          installation_mode = "force_installed";
          default_area = "navbar";
        };
        "ncpasswords@mdns.eu" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/nextcloud-passwords/latest.xpi";
          installation_mode = "force_installed";
          default_area = "navbar";
        };
      };

      Preferences = {
        "browser.aboutConfig.showWarning" = {
          Value = false;
          Status = "locked";
        };
        "browser.tabs.warnOnClose" = {
          Value = false;
          Status = "locked";
        };
      };
    };

    profiles.default = {
      settings = {
        "zen.welcome-screen.seen" = true;
        
        "zen.tabs.vertical.right-side" = true;
        "zen.sidebar.enabled" = false;
        "zen.sidebar.close-on-blur" = false;
        
        "zen.workspaces.continue-where-left-off" = true;
        "zen.workspaces.show-workspace-indicator" = false;
        
        "browser.startup.page" = 3;
        "browser.sessionstore.resume_from_crash" = true;
        
        "browser.urlbar.suggest.bookmark" = false;
        "browser.urlbar.suggest.engines" = false;
        "browser.urlbar.suggest.history" = false;
        "browser.urlbar.suggest.searches" = false;
        "browser.urlbar.suggest.topsites" = false;
        "browser.urlbar.suggest.openpage" = true;
        "browser.urlbar.showSearchSuggestionsFirst" = false;
        
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.topsites.contile.enabled" = false;
      };

      spacesForce = false;
      spaces = {
        "Personal" = {
          id = "2a8bdc6d-b897-4614-bc9b-1a9eeea84b98";
          icon = "🏠";
          position = 1000;
        };
        "Work" = {
          id = "d5024a4e-57b2-48fe-bbe3-08e1530b1d8b";
          icon = "💼";
          position = 2000;
        };
      };

      search = {
        force = true;
        default = "ddg";
        
        engines = {
          "Nix Packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [
                { name = "type"; value = "packages"; }
                { name = "channel"; value = "unstable"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@np"];
          };
          
          "Nix Options" = {
            urls = [{
              template = "https://search.nixos.org/options";
              params = [
                { name = "channel"; value = "unstable"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@no"];
          };
          
          "Home Manager Options" = {
            urls = [{
              template = "https://home-manager-options.extranix.com/";
              params = [
                { name = "query"; value = "{searchTerms}"; }
                { name = "release"; value = "master"; }
              ];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@hm"];
          };
          
          "GitHub" = {
            urls = [{
              template = "https://github.com/search";
              params = [
                { name = "q"; value = "{searchTerms}"; }
              ];
            }];
            definedAliases = ["@gh"];
          };
        };
      };

      bookmarks = {
        force = false;
        settings = [];
      };

      pinsForce = false;
      pins = {};

      containersForce = false;
      containers = {};
    };
  };
}
