#
# Makima configuration (macOS)
#
# This is the system-level configuration for the Makima host.
# User-level configuration is in ./home.nix
#
{
  # Import system modules to compose the configuration
  # Modules are evaluated in order - later ones can override earlier ones
  imports = [
    ../../modules/darwin/minimal.nix
  ];
}
