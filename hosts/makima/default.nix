#
# Makima configuration (macOS)
#
# This is the system-level configuration for the Makima host.
# User-level configuration is in ./home.nix
#
# System utilities and apps are organized by category under darwin.apps:
# - darwin.apps.internet.*       - Web browsers and internet apps
# - darwin.apps.system.*         - System-level tools (aldente, karabiner, insync)
# - darwin.apps.windowManager.*  - Window management (raycast, altTab, blurred)
# - darwin.apps.development.*    - Development tools
# - darwin.apps.media.*          - Media applications
#
# Note: Installation source (Nix vs Homebrew) is abstracted away
#
{
  # Import system modules to compose the configuration
  # Modules are evaluated in order - later ones can override earlier ones
  imports = [
    ../../modules/darwin/minimal.nix
    ../../modules/darwin/apps
    ../../modules/shared/apps
  ];

  darwin.apps = {
    system = {
      ice.enable = true;
    };

    windowManager = {
      raycast.enable = true;
      altTab.enable = true;
    };
  };
  
  darwin.internet = {
    microsoft-teams.enable = true;
    microsoft-outlook.enable = true;
  };

  shared.apps = { };

  # https://mynixos.com/nix-darwin/options/system.defaults.NSGlobalDomain
  system.defaults.NSGlobalDomain = {
    "com.apple.swipescrolldirection" = false;
    KeyRepeat = 2;
    InitialKeyRepeat = 15;
    ApplePressAndHoldEnabled = false;
    NSAutomaticDashSubstitutionEnabled = false;
    NSAutomaticQuoteSubstitutionEnabled = false;
    NSAutomaticSpellingCorrectionEnabled = false;
  };

  # https://mynixos.com/nix-darwin/options/system.defaults.screensaver
  system.defaults.screensaver.askForPassword = true;

  # Not typed by nix-darwin → routed through CustomUserPreferences.
  system.defaults.CustomUserPreferences.NSGlobalDomain = {
    AppleMiniaturizeOnDoubleClick = false;
    "com.apple.scrollwheel.scaling" = 2.0;
  };

  # No .DS_Store on network shares or USB volumes.
  system.defaults.CustomUserPreferences."com.apple.desktopservices" = {
    DSDontWriteNetworkStores = true;
    DSDontWriteUSBStores = true;
  };

  # Free ⌘+Space (and ⌘+⌥+Space) so Raycast can claim them without contest.
  # Nix-copied apps change signature/inode each rebuild → macOS revokes
  # hotkey grants unless the competing system binding is disabled outright.
  system.defaults.CustomUserPreferences."com.apple.symbolichotkeys" = {
    AppleSymbolicHotKeys = {
      "64" = { enabled = false; };
      "65" = { enabled = false; };
    };
  };

  # Hide Spotlight from the menu bar.
  system.defaults.CustomUserPreferences."com.apple.Spotlight" = {
    "NSStatusItem VisibleCC Item-0" = 0;
  };

  # https://mynixos.com/nix-darwin/options/system.defaults.finder
  system.defaults.finder = {
    AppleShowAllExtensions = false;
    AppleShowAllFiles = false;
    ShowPathbar = true;
    ShowStatusBar = true;
    FXPreferredViewStyle = "Nlsv";
    FXDefaultSearchScope = "SCcf";
    _FXShowPosixPathInTitle = true;
  };

  # https://mynixos.com/nix-darwin/options/system.defaults.trackpad
  system.defaults.trackpad = {
    Clicking = true;
    TrackpadThreeFingerDrag = true;
  };

  # https://mynixos.com/nix-darwin/options/system.defaults.screencapture
  system.defaults.screencapture = {
    location = "~/Pictures/Screenshots";
    type = "png";
    disable-shadow = true;
  };

  # https://mynixos.com/nix-darwin/options/system.defaults.menuExtraClock
  system.defaults.menuExtraClock = {
    Show24Hour = true;
    ShowDate = 1;
    ShowSeconds = false;
  };

  # https://mynixos.com/nix-darwin/options/system.defaults.SoftwareUpdate
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

  # https://mynixos.com/nix-darwin/options/system.defaults.CustomUserPreferences
  system.defaults.CustomUserPreferences."com.lwouis.alt-tab-macos" = {
    SUAutomaticallyUpdate = 0;
    SUEnableAutomaticChecks = false;
    menubarIcon = 2;
    updatePolicy = 1;
    screenRecordingPermissionSkipped = true;
  };

  system.defaults.CustomUserPreferences."com.jordanbaird.Ice" = {
    SUAutomaticallyUpdate = false;
    SUEnableAutomaticChecks = false;
    SUHasLaunchedBefore = true;
    ShowIceIcon = true;
    CustomIceIconIsTemplate = false;
    ShowSectionDividers = false;
    EnableAlwaysHiddenSection = false;
    CanToggleAlwaysHiddenSection = true;
    ShowAllSectionsOnUserDrag = true;
    ShowOnClick = true;
    ShowOnHover = false;
    ShowOnHoverDelay = 0.2;
    ShowOnScroll = true;
    AutoRehide = true;
    RehideInterval = 15.0;
    RehideStrategy = 0;
    TempShowInterval = 15.0;
    IceBarLocation = 0;
    UseIceBar = false;
    ItemSpacingOffset = 0.0;
    HideApplicationMenus = true;
  };

  system.defaults.CustomUserPreferences."com.mitchellh.ghostty" = {
    SUEnableAutomaticChecks = false;
    SUSendProfileInfo = false;
  };

  system.defaults.CustomUserPreferences."com.raycast.macos" = {
    raycastGlobalHotkey = "Command-49";
    raycastPreferredWindowMode = "default";
    raycastShouldFollowSystemAppearance = true;
    useHyperKeyIcon = false;
  };
}
