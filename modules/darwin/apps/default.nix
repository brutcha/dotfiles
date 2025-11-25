#
# macOS applications module aggregator
#
# Combines all darwin.apps.* modules.
#
{
  imports = [
    ./system.nix
    ./window-manager.nix
    ./development.nix
  ];
}
