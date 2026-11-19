#
# Homebrew configuration and automatic package detection
#
# This module:
# 1. Configures Homebrew to install and manage taps, casks, and formulas declaratively
# 2. Automatically detects packages in environment.systemPackages that have
#    passthru.brewTap, passthru.brewCask, or passthru.brewFormula attributes
#
# This allows packages to declare their Homebrew installation method in pkgs/
# while modules simply use environment.systemPackages without needing to know
# about the installation source.
#
{ config, lib, ... }:
{
  config = {
    # Enable Homebrew package installation and management
    homebrew = {
      enable = true;
      
      # Automatically install, upgrade, and clean up packages on activation
      onActivation = {
        autoUpdate = false;  # Don't auto-update Homebrew itself
        upgrade = true;      # Upgrade outdated packages
        cleanup = "zap";     # Remove unlisted packages and cask data
      };
      
      # Global Homebrew settings
      global = {
        autoUpdate = false;
      };
      
      # Collect requested Homebrew sources from all system packages.
      taps = lib.unique (lib.filter (x: x != null) (
        map (pkg: pkg.passthru.brewTap or null) config.environment.systemPackages
      ));
      casks = lib.unique (lib.filter (x: x != null) (
        map (pkg: pkg.passthru.brewCask or null) config.environment.systemPackages
      ));
      brews = lib.unique (lib.filter (x: x != null) (
        map (pkg: pkg.passthru.brewFormula or null) config.environment.systemPackages
      ));
    };
  };
}
