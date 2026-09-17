#
# macOS (nix-darwin) minimal platform configuration
#
# Platform-specific settings for macOS system configuration
#
{ config, lib, ... }:
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

  # Weekly garbage collection + store optimisation to reclaim disk
  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 3; Minute = 0; };
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  # Also GC on every darwin-rebuild switch — machine is awake and a delay is expected
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    echo "Collecting nix garbage older than 30d..." >&2
    ${config.nix.package}/bin/nix-collect-garbage --delete-older-than 30d
  '';

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
