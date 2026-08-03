{ helpers, lib, stdenv, fetchurl, appimageTools, makeWrapper }:
#
# Emdash — multi-agent dev environment (https://emdash.sh)
#
# Not in nixpkgs. macOS uses the Homebrew cask (Microsoft-style auto-update,
# signed installer); Linux fetches the upstream AppImage and wraps it.
#
# Telemetry: opt out once in the in-app Settings panel. The build-time
# Info.plist LSEnvironment tweak we previously had on darwin doesn't survive
# brew-managed installs (brew replaces the bundle on each upgrade).
#
# Linux still gets the AppImage path with TELEMETRY_ENABLED=false wired into
# the wrapper. Update procedure for Linux:
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
    version = "1.1.35";
    src = fetchurl {
      url = "https://github.com/generalaction/emdash/releases/download/v${version}/emdash-x86_64.AppImage";
      hash = "sha256-54Z6iAZCv7njTQ/YRGQOm+ntOLjtYTgxa+Rd7oPpxv0=";
    };
    base = appimageTools.wrapType2 {
      pname = "emdash";
      inherit version src;
      meta = {
        description = "Open-source agentic development environment";
        homepage = "https://emdash.sh";
        license = lib.licenses.mit;
        platforms = [ "x86_64-linux" ];
        mainProgram = "emdash";
      };
    };
  in
  base.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ makeWrapper ];
    postInstall = (old.postInstall or "") + ''
      wrapProgram $out/bin/emdash --set TELEMETRY_ENABLED false
    '';
  })
