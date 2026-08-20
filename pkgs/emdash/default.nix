{ helpers, lib, stdenv, fetchurl, appimageTools }:
#
# Emdash — multi-agent dev environment (https://emdash.sh)
#
# Not in nixpkgs. macOS uses the Homebrew cask; Linux fetches the upstream
# AppImage and wraps it.
#
# Telemetry: opt out once in the in-app Settings panel. The build-time
# Info.plist LSEnvironment tweak we previously had on darwin doesn't survive
# brew-managed installs (brew replaces the bundle on each upgrade).
#
# Linux still gets the AppImage path with TELEMETRY_ENABLED=false set via the
# FHS env's profile. Update procedure for Linux:
#   nix store prefetch-file --json \
#     https://github.com/generalaction/emdash/releases/download/v<NEW>/emdash-x86_64.AppImage
#
let
  cfg = helpers.darwin;
in
if stdenv.hostPlatform.isDarwin then
  cfg.mkBrewCask { caskName = "emdash"; }
else
  let
    version = "1.1.40";
    src = fetchurl {
      url = "https://github.com/generalaction/emdash/releases/download/v${version}/emdash-x86_64.AppImage";
      hash = "sha256-8QT0zdyyQOy69Ez5QnEePhG1SvIH6sfXiXn+Nq4N52M=";
    };
  in
  appimageTools.wrapType2 {
    pname = "emdash";
    inherit version src;

    # Not postInstall/wrapProgram: wrapType2's FHS env is built by buildCommand,
    # so stdenv install hooks never fire and the wrapper is silently dropped.
    profile = "export TELEMETRY_ENABLED=false";

    meta = {
      description = "Open-source agentic development environment";
      homepage = "https://emdash.sh";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      mainProgram = "emdash";
    };
  }
