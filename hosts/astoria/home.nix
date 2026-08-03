{ config, pkgs, ... }:
#
# astoria — home-manager entry for `brutcha`.
#
# Toggles the fleet-standard `home.apps.*` options; modules/home/default.nix
# picks the linux sub-bundle (sway/waybar/mako/fuzzel/swaylock/screenshot/
# thunar/librewolf/moonlight/imv) via `hostSystem`.
#
{
  imports = [ ../../modules/home ];

  home.apps = {
    development = {
      ghostty.enable = true;
      git.enable     = true;
      claude-code.enable = true;
    };
    internet.librewolf.enable = true;
    media.moonlight.enable    = true;
    media.imv.enable          = true;
    filemanager.thunar.enable = true;
    windowManager = {
      sway.enable       = true;
      waybar.enable     = true;
      mako.enable       = true;
      fuzzel.enable     = true;
      swaylock.enable   = true;
      screenshot.enable = true;
    };
  };

  home.stateVersion = "26.11";
  home.username = "brutcha";
  home.homeDirectory = "/home/brutcha";

  # --- GTK theming ---
  # Cross-cutting; not owned by any single app module.
  # `tweakVariants = ["black"]` modifies the theme's internal palette but
  # does NOT change the folder name (install.sh: "${name}${theme}${color}${size}${ctype}"
  # → "Tokyonight-Dark").
  gtk = {
    enable = true;
    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyonight-gtk-theme.override {
        colorVariants = [ "dark" ];
        sizeVariants  = [ "standard" ];
        tweakVariants = [ "black" ];
      };
    };
    iconTheme   = { name = "Papirus-Dark";      package = pkgs.papirus-icon-theme; };
    cursorTheme = { name = "Bibata-Modern-Ice"; package = pkgs.bibata-cursors; };
    # Matches the Nerd Font used across sway/waybar/mako/fuzzel.
    font = { name = "JetBrainsMonoNL Nerd Font"; size = 10; };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  # Portal color-scheme signal — what Ghostty/LibreWolf actually consult
  # for dark mode on Wayland, unlike the GTK3-only setting above.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };

  # File-sync client. Server URL + creds set on first launch.
  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
