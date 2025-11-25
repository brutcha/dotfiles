#
# macOS development environment configuration
#
{
  # TUI for Docker management
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.lazydocker.enable
  # Enable manually when using Docker
  programs.lazydocker = {
    enable = true;
  };

  imports = [
    ./default.nix
  ];
}
