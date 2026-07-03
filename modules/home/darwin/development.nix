{ config, osConfig, lib, pkgs, ... }:
#
# macOS-only development extras
#
# Available options:
# - home.apps.development.lazydocker.enable            - TUI for Docker; auto-on when
#   shared.apps.development.docker or darwin.apps.development.orbstack is enabled
# - home.apps.development.xcbuild.enable               - xcrun shim, default true on darwin
# - home.apps.development.androidStudio.telemetry.optOut - lock the IDE +
#   SDK-tools telemetry files to opt-out; auto-on when
#   darwin.apps.development.android-studio.enable = true
#
let
  cfg = config.home.apps.development;
in
{
  # ./default.nix is imported by modules/home/default.nix — don't re-import here.

  options.home.apps.development = {
    lazydocker.enable = lib.mkOption {
      type = lib.types.bool;
      default =
        (osConfig.shared.apps.development.docker.enable or false)
        || (osConfig.darwin.apps.development.orbstack.enable or false);
      description = "Install lazydocker. Auto-enables when docker/orbstack is on.";
    };
    xcbuild.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.home.apps.development.direnv.enable;
      description = "xcbuild — nix `xcrun` shim. Auto-enables with direnv (dev-shells usually need native builds).";
    };
    androidStudio.telemetry.optOut = lib.mkOption {
      type = lib.types.bool;
      default = osConfig.darwin.apps.development.android-studio.enable or false;
      description = "Pre-write Android Studio's data-sharing opt-out so the first-run telemetry prompt never appears.";
    };
  };

  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkMerge [
    (lib.mkIf cfg.lazydocker.enable {
      programs.lazydocker.enable = true;
    })

    (lib.mkIf cfg.xcbuild.enable {
      home.packages = [ pkgs.xcbuild ];
    })

    # Opt out of Android Studio telemetry. `consentOptions/accepted` gates the
    # IDE prompt (JetBrains platform); `.android/analytics.settings` gates the
    # SDK-tools pipeline. 0444 after write so Studio can't reset either.
    (lib.mkIf cfg.androidStudio.telemetry.optOut {
      home.activation.androidStudioTelemetryOptOut =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          accepted="$HOME/Library/Application Support/Google/consentOptions/accepted"
          $DRY_RUN_CMD mkdir -p "$(dirname "$accepted")"
          tmp="$(mktemp)"
          if [ -f "$accepted" ]; then
            $DRY_RUN_CMD chmod u+w "$accepted" 2>/dev/null || true
            ${pkgs.gnugrep}/bin/grep -v '^rsch\.send\.usage\.stat:' "$accepted" > "$tmp" || true
          fi
          printf 'rsch.send.usage.stat:1.0:0:0\n' >> "$tmp"
          $DRY_RUN_CMD mv "$tmp" "$accepted"
          $DRY_RUN_CMD chmod 0444 "$accepted"

          settings="$HOME/.android/analytics.settings"
          $DRY_RUN_CMD mkdir -p "$(dirname "$settings")"
          tmp="$(mktemp)"
          if [ -f "$settings" ]; then
            $DRY_RUN_CMD chmod u+w "$settings" 2>/dev/null || true
            if ${pkgs.jq}/bin/jq \
                 '.hasOptedIn = false | .debugDisablePublishing = false | .lastOptinPromptVersion = "9999.9"' \
                 "$settings" > "$tmp"; then
              $DRY_RUN_CMD mv "$tmp" "$settings"
            else
              rm -f "$tmp"
              echo "warn: jq failed to transform $settings; leaving file as-is" >&2
            fi
          else
            printf '%s\n' '{"hasOptedIn":false,"debugDisablePublishing":false,"lastOptinPromptVersion":"9999.9"}' > "$tmp"
            $DRY_RUN_CMD mv "$tmp" "$settings"
          fi
          $DRY_RUN_CMD chmod 0444 "$settings"
        '';
    })
  ]);
}
