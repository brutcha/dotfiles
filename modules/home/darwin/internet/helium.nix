{ config, inputs, pkgs, lib, ... }:
#
# Helium browser (https://helium.computer)
#
# Available options:
# - home.apps.internet.helium.enable - Install Helium and merge declared prefs/flags
#
# Sourced from inputs.helium-flake (not in nixpkgs). Bump with `nix flake update helium-flake`.
# Close Helium before `darwin-rebuild switch` — running browser overwrites
# the prefs merge on next quit.
# Extensions install at helium://extensions (Chrome Web Store proxied via
# Helium Services). Enterprise policies don't survive corp MDM filtering.
#
let
  cfg = config.home.apps.internet.helium;

  bundleId = "net.imput.helium";

  # Per-profile Helium/HOP prefs, deep-merged into Default/Preferences on
  # rebuild. Full catalog at
  # https://deepwiki.com/imputnet/helium-chromium/5-helium-customizations
  prefsOverrides = {
    browser.theme.is_grayscale2 = true;            # grayscale theme.            default: false
    vertical_tabs = {
      collapsed_state   = false;                   # sidebar starts expanded.   default: true(?)
      uncollapsed_width = 200;                     # sidebar width.             default: ~250
    };

    helium.completed_onboarding = true;            # skip welcome UI.           default: false

    helium.services = {
      # enabled = true;                            # master switch. default true; false breaks ext install.
      user_consented   = true;                     # skip consent prompt.       default: false
      # origin_override = "";                      # self-hosted Helium Services. default: ""
      bangs            = false;                    # !bang shortcuts.           default: true
      # ext_proxy      = true;                     # CWS proxy. KEEP true.      default: true
      spellcheck_files = false;                    # dict downloads.            default: true
      browser_updates  = false;                    # update nag.                default: true
      ublock_assets    = false;                    # uBlock filter refresh.     default: true
    };

    spellcheck.dictionaries = [ "cs" ];            # default: ["en-US"]
    # intl.selected_languages = "cs-CZ,cs";        # default: en-US,en

    # Helium UI prefs (verified by reading live Preferences after toggling UI):
    # browser.centered_location_bar      = false;  # default: false
    # browser.minimal_location_bar       = true;   # default: true
    # browser.rounded_frame              = true;   # default: true
    # browser.vertical_right_aligned     = true;   # default: true
    # browser.zen_mode                   = false;  # Frameless mode. default: false
    # browser.zen_mode_sidebar_pinned    = false;
    # browser.zen_mode_top_chrome_pinned = false;
    # browser.layout                     = 2;      # 0=Classic, 1=Compact, 2=Vertical
  };

  prefsOverridesJson = builtins.toJSON prefsOverrides;

  # chrome://flags persistence (browser-wide Local State).
  # Slug from helium://flags#<slug>; @N is the variant index.
  flagOverrides = {
    browser.enabled_labs_experiments = [
      # "side-by-side@1"
      # "frameless@1"
    ];
  };

  flagOverridesJson = builtins.toJSON flagOverrides;
in
{
  options.home.apps.internet.helium.enable =
    lib.mkEnableOption "Helium browser + declarative HOP prefs/flag merges";

  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    home.packages = [
      inputs.helium-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    home.activation.heliumPrefsMerge =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        prefsPath="$HOME/Library/Application Support/${bundleId}/Default/Preferences"
        if [ -f "$prefsPath" ]; then
          if pgrep -x "Helium" >/dev/null 2>&1; then
            echo "warning: Helium is running; merged prefs may be clobbered when it exits." >&2
          fi
          tmp="$(mktemp)"
          ${pkgs.jq}/bin/jq --argjson o ${lib.escapeShellArg prefsOverridesJson} \
            '. * $o' "$prefsPath" > "$tmp"
          $DRY_RUN_CMD mv "$tmp" "$prefsPath"
        fi
      '';

    home.activation.heliumLocalStateMerge =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        statePath="$HOME/Library/Application Support/${bundleId}/Local State"
        if [ -f "$statePath" ]; then
          tmp="$(mktemp)"
          ${pkgs.jq}/bin/jq --argjson o ${lib.escapeShellArg flagOverridesJson} \
            '. * $o' "$statePath" > "$tmp"
          $DRY_RUN_CMD mv "$tmp" "$statePath"
        fi
      '';
  };
}
