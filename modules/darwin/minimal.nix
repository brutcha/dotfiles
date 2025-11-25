#
# macOS (nix-darwin) minimal platform configuration
#
# Platform-specific settings for macOS system configuration
#
{ lib, ... }:
{
  imports = [
    ./services/karabiner-elements-fixed.nix
    ./homebrew.nix
  ];

  # Target platform for the system
  # aarch64-darwin = Apple Silicon (M series)
  # x86_64-darwin = Intel Mac
  # https://github.com/LnL7/nix-darwin
  nixpkgs.hostPlatform = "aarch64-darwin";

  # System state version for nix-darwin compatibility
  # Determines which behavior and defaults to use
  # Increment only after reading changelog: darwin-rebuild changelog
  # https://github.com/LnL7/nix-darwin/releases
  system.stateVersion = 6;

  # Re-sign apps copied to /Applications to fix signature issues
  # macOS validates app signatures and nix-copied apps lose their original signatures
  system.activationScripts.applications.text = lib.mkAfter ''
    echo "Re-signing applications..." >&2
    for app in /Applications/Nix\ Apps/*.app; do
      if [ -d "$app" ]; then
        echo "  Signing $(basename "$app")..." >&2
        /usr/bin/codesign --force --deep --sign - "$app" 2>/dev/null || true
      fi
    done
  '';
}
