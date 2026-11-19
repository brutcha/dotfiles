{ lib }:
#
# Custom utility functions
#
# Global utilities available across the entire configuration via the `helpers` special arg.
# Imported in flake.nix and passed to all modules via specialArgs.
#
# These utilities are system-wide and available to both nix-darwin and home-manager modules.
#
{
  colors = {
    # Convert hex color with alpha to ARGB format
    #
    # Converts a hex color string and alpha value (0.0-1.0) to ARGB format
    # commonly used in macOS applications like SketchyBar.
    #
    # Arguments:
    #   hex   - Hex color string with or without '#' prefix (e.g., "#ff0000" or "ff0000")
    #   alpha - Alpha value between 0.0 (transparent) and 1.0 (opaque)
    #
    # Returns:
    #   String in ARGB format: "0xAARRGGBB" where AA is alpha in hex
    #
    # Examples:
    #   toARGB "#ff0000" 1.0   => "0xffff0000" (opaque red)
    #   toARGB "#00ff00" 0.5   => "0x7f00ff00" (50% transparent green)
    #   toARGB "0000ff" 0.25   => "0x3f0000ff" (25% opaque blue)
    #
    toARGB = hex: alpha: let
      cleanHex = lib.removePrefix "#" hex;
      alpha255 = builtins.floor (alpha * 255);
      alphaHex = lib.toHexString alpha255;
      paddedAlpha = if alpha255 < 16 then "0${alphaHex}" else alphaHex;
    in "0x${paddedAlpha}${cleanHex}";
  };

  darwin = {
    # Build a macOS application from a DMG file
    #
    # Uses macOS native hdiutil to mount and extract DMG files, supporting both
    # HFS+ and APFS filesystems. This replaces the nixpkgs `undmg` which only
    # supports HFS+ and causes malformed Info.plist files with APFS DMGs.
    #
    # Arguments:
    #   stdenv  - Standard environment for building
    #   fetchurl - Function to fetch the DMG file
    #   args - Attribute set with:
    #     - pname: Package name
    #     - version: Package version
    #     - src: DMG source (from fetchurl)
    #     - appname: Name of the .app bundle in the DMG (e.g., "Insync.app")
    #     - meta: Package metadata
    #     - installPhaseExtras: (optional) Extra commands to run after copying the app
    #
    # Returns:
    #   A derivation that installs the macOS application
    #
    # Example:
    #   helpers.darwin.mkDmgApp {
    #     inherit stdenv fetchurl;
    #     pname = "insync";
    #     version = "3.8.7.50505";
    #     src = fetchurl { url = "..."; sha256 = "..."; };
    #     appname = "Insync.app";
    #     meta = { description = "..."; };
    #   }
    #
    mkDmgApp = { stdenv, fetchurl, pname, version, src, appname, meta, installPhaseExtras ? "" }:
      stdenv.mkDerivation {
        inherit pname version src meta;

        dontUnpack = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mnt=$(mktemp -d)
          /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$src"
          mkdir -p "$out/Applications"
          cp -R "$mnt/${appname}" "$out/Applications/"
          /usr/bin/hdiutil detach "$mnt"

          ${installPhaseExtras}

          runHook postInstall
        '';
      };

    # Create a Homebrew package marker.
    #
    # Homebrew installs the actual package. This marker tells the Homebrew
    # module which tap, cask, and/or formula to add.
    #
    # This approach maintains the abstraction where installation sources are defined
    # in pkgs/ while keeping the current module structure unchanged.
    #
    # Arguments:
    #   tapName - The optional Homebrew tap name
    #   caskName - The optional Homebrew cask name
    #   formulaName - The optional Homebrew formula name
    #
    # Returns:
    #   A marker derivation with the package name in passthru
    #
    # Example:
    #   helpers.darwin.mkBrewPkg { caskName = "karabiner-elements"; }
    #   helpers.darwin.mkBrewPkg { formulaName = "workmux"; }
    #
    # Usage in modules:
    #   When a package created with mkBrewPkg is added to environment.systemPackages,
    #   the module should check its passthru marker and add it to Homebrew.
    #
    mkBrewPkg = { tapName ? null, caskName ? null, formulaName ? null }:
      assert lib.assertMsg (caskName != null || formulaName != null)
        "mkBrewPkg: set caskName or formulaName";
      let
        name = if caskName != null then caskName else formulaName;
      in lib.trivial.pipe name [
        (name: {
          # Create a minimal marker derivation
          type = "derivation";
          name = name;
          system = "aarch64-darwin";
          # Use placeholder paths since this won't actually be built
          drvPath = "/nix/store/00000000000000000000000000000000-${name}.drv";
          outPath = "/nix/store/00000000000000000000000000000000-${name}";
          
          # Store the Homebrew package name for modules to detect
          passthru = lib.optionalAttrs (caskName != null) {
            brewCask = caskName;
          } // lib.optionalAttrs (formulaName != null) {
            brewFormula = formulaName;
          } // lib.optionalAttrs (tapName != null) {
            brewTap = tapName;
          };
          
          meta = {
            description = "Homebrew package: ${name}";
            platforms = lib.platforms.darwin;
            license = lib.licenses.unfree;
          };
        })
      ];
  };
}
