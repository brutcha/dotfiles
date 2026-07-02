{ ... }:
#
# Shared home-manager modules (platform-generic). Opt-in per app via
# home.apps.<category>.<app>.enable. Darwin-only extras live in ./darwin/.
#
{
  imports = [
    ./theme.nix
    ./fonts.nix
    ./shell.nix
    ./development
  ];
}
