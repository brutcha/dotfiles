#
# macOS (nix-darwin) minimal platform configuration
#
# Platform-specific settings for macOS system configuration
#
{
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
}
