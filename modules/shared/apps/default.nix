{ config, lib, ... }:
#
# Cross-platform applications module aggregator
#
# Combines all shared.apps.* modules.
# These modules work across both macOS (nix-darwin) and Linux (NixOS).
#
{
  imports = [
    ./internet.nix
    ./development.nix
    ./system.nix
  ];
}
