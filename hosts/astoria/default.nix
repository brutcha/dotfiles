{ config, pkgs, lib, inputs, ... }:
#
# astoria — Dell XPS 13 9300 NixOS thin-client. Sway sole session,
# Moonlight-first, LibreWolf, greetd, no autologin.
#
# System composition + non-hardware config. Hardware knobs + disko live
# in ./hardware.nix. Sops secret declarations in ./secrets.nix.
#
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    ./hardware.nix
    ./secrets.nix
  ];

  nixpkgs.config.allowUnfree = true;                # required by hardware.enableAllFirmware
  nixpkgs.overlays = [ inputs.nur.overlays.default ];

  networking.hostName = "astoria";

  # --- Locale / timezone / console ---
  time.timeZone = "Europe/Prague";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocales = [ "cs_CZ.UTF-8/UTF-8" ];
  i18n.extraLocaleSettings = {
    LC_TIME = "cs_CZ.UTF-8";
    LC_NUMERIC = "cs_CZ.UTF-8";
  };
  console.keyMap = "us";                            # LUKS prompt reads from this

  # --- User (password from sops — see ./secrets.nix) ---
  users.mutableUsers = false;
  users.users.brutcha = {
    isNormalUser = true;
    description = "brutcha";
    extraGroups = [ "wheel" "video" "input" "render" "audio" "networkmanager" ];
    shell = pkgs.zsh;
    hashedPasswordFile = config.sops.secrets."users/brutcha/hashed-password".path;
    # Fill in Nobara's pubkey after first boot (README Phase 4a).
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA...  brutcha@nobara"
    ];
  };
  programs.zsh.enable = true;                       # REQUIRED when user shell = pkgs.zsh

  # --- Sway via greetd tuigreet (no autologin — password muscle memory) ---
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd sway";
      user = "greeter";
    };
  };

  # --- XDG portals + polkit ---
  # `common.default` catches processes that spawn before Sway exports
  # XDG_CURRENT_DESKTOP — without it portal resolution is nondeterministic.
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      sway.default   = lib.mkForce [ "wlr" "gtk" ];
      common.default = [ "wlr" "gtk" ];
    };
  };
  security.polkit.enable = true;

  # --- System packages ---
  environment.systemPackages = with pkgs; [
    intel-gpu-tools     # intel_gpu_top for VA-API verification
    brightnessctl       # sway XF86MonBrightness keybinds
    sbctl               # Secure Boot key management
    tpm2-tools          # TPM inspection + re-enrollment
    pavucontrol         # waybar pulseaudio click target
  ];
  # brightnessctl's udev rule gives `video` group write access to
  # /sys/class/backlight — services.udev scans only .packages (NOT
  # environment.systemPackages), so it must be listed here explicitly.
  services.udev.packages = [ pkgs.brightnessctl ];
  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "iHD";                     # Ice Lake Gen 11+
  };

  # --- Audio (PipeWire) ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    extraConfig.pipewire."92-video-streaming"."context.properties" = {
      "default.clock.rate"          = 48000;
      "default.clock.allowed-rates" = [ 44100 48000 ];
      "default.clock.quantum"       = 512;
      "default.clock.min-quantum"   = 128;
      "default.clock.max-quantum"   = 2048;
    };
  };

  # --- Credential agents ---
  # NOT setting programs.ssh.startAgent: gnome-keyring-daemon's ssh
  # component already exports SSH_AUTH_SOCK; enabling both spawns two
  # agents that race for the socket.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # --- SSH (for --target-host rebuilds from LAN) ---
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # --- Nix ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "brutcha" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  # --- Disk / filesystem maintenance ---
  services.fstrim.enable = true;
  services.btrfs.autoScrub.enable = true;

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    MaxRetentionSec=1month
  '';

  # --- Sway ancillary services ---
  services.upower.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.smartd = {
    enable = true;
    notifications.mail.enable = false;              # no MTA — don't spam journal with sendmail failures
    notifications.wall.enable = true;
  };
  services.avahi = { enable = true; nssmdns4 = true; };

  # --- Snapper (on-boot snapshot only, no timeline) ---
  # Without snapshotRootOnBoot (or a timeline / activation script) the
  # snapper module installs the daemon + cleanup timer but nothing creates
  # snapshots — NUMBER_LIMIT would be meaningless.
  services.snapper.snapshotRootOnBoot = true;
  services.snapper.configs.root = {
    SUBVOLUME = "/";
    ALLOW_USERS = [ "brutcha" ];
    TIMELINE_CREATE = false;
    TIMELINE_CLEANUP = false;
    NUMBER_CLEANUP = true;
    NUMBER_LIMIT = 20;
  };
  services.snapper.cleanupInterval = "1d";

  programs.nix-index.enable = true;
  programs.command-not-found.enable = false;

  # --- Restic backups (secrets from sops) ---
  # Daily backup, weekly prune. `initialize = true` on prune too — idempotent
  # (`restic cat config || restic init`), so prune doesn't fail-loop if the
  # daily backup never bootstrapped the repo.
  services.restic.backups.webdav = {
    initialize = true;
    repository = "rclone:webdav:restic-astoria";
    paths = [
      "/home/brutcha/.ssh"
      "/home/brutcha/.local/share/keyrings"
      "/home/brutcha/.zsh_history"
    ];
    extraBackupArgs = [ "--one-file-system" ];
    passwordFile = config.sops.secrets."restic/repo-password".path;
    rcloneConfigFile = config.sops.secrets."rclone/webdav.conf".path;
    timerConfig = { OnCalendar = "daily"; Persistent = true; RandomizedDelaySec = "30m"; };
  };
  services.restic.backups.webdav-prune = {
    initialize = true;
    repository = "rclone:webdav:restic-astoria";
    passwordFile = config.sops.secrets."restic/repo-password".path;
    rcloneConfigFile = config.sops.secrets."rclone/webdav.conf".path;
    paths = [];
    timerConfig = { OnCalendar = "weekly"; Persistent = true; RandomizedDelaySec = "1h"; };
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 12" "--keep-within 30d" ];
  };

  # /home/brutcha/git/dotfiles is populated in README Phase 4a; broken
  # symlink until then (cosmetic warning only).
  environment.etc.nixos.source = "/home/brutcha/git/dotfiles";

  # --- Home Manager ---
  # `home-manager.extraSpecialArgs` (including `inputs` + `hostSystem`) is
  # wired from flake.nix — shared HM modules destructure `{ inputs, ... }:`
  # at pattern-match, and modules/home/default.nix uses `hostSystem` to
  # select the platform sub-bundle.
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager.users.brutcha = import ./home.nix;

  system.stateVersion = "26.11";
}
