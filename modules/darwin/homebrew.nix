#
# Homebrew configuration and automatic cask detection
#
# This module:
# 1. Configures Homebrew to install and manage casks declaratively
# 2. Automatically detects packages in environment.systemPackages that have
#    a passthru.brewCask attribute and adds them to homebrew.casks
#
# This allows packages to declare their Homebrew installation method in pkgs/
# while modules simply use environment.systemPackages without needing to know
# about the installation source.
#
{ config, lib, ... }:
{
  config = {
    # Enable Homebrew cask installation and management
    homebrew = {
      enable = true;
      
      # Automatically install/upgrade/cleanup on activation
      onActivation = {
        autoUpdate = false;  # Don't auto-update Homebrew itself
        upgrade = true;      # Upgrade outdated casks
        cleanup = "zap";     # Remove unlisted casks and their data
      };
      
      # Global Homebrew settings
      global = {
        autoUpdate = false;
      };
      
      # Automatically extract Homebrew cask names from all system packages
      # Filter out null values (packages without passthru.brewCask)
      casks = lib.filter (x: x != null) (
        map (pkg: pkg.passthru.brewCask or null) config.environment.systemPackages
      );
    };
  };
}
