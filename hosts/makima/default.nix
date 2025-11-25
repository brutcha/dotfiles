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
# TODO add following programs
# ------- BROWSING & COMUNICATIONS -------
# ✅ Zen Browser - Comunity flake
# 🔄 Thunderbird - Home Manager
# ✅ Discord - Home Manager
# ✅ Telegram - Nixpkgs
# ✅ Slack - Nixpkgs
# ✅ Proton Mail Bridge - Nixpkgs
# ------------ DEVELOPMENT ---------------
# ✅ Postman - Nixpkgs
# ✅ Chromium - Brew
# ✅ Lazydocker - Nixpkgs
# ✅ Orbstack - Brew
# ✅ Antigravity - Nixpkgs
# -------------- SYSTEM ------------------
# ✅ AlDente - Nixpkgs
# ✅ Insync - Brew
# ✅ Karabiner Elements - Brew
# ✅ Better touch tools - Brew
# -------------- MEDIA -------------------
# 🔄 Elgato Control Center - Nixpkgs 🙏
# 🔄 Figma - Nixpkgs
# 🔄 Spotify - Nixpkgs
# 🔄 OBS Studio - Home Manager
# 🔄 OBS virtualcam - Not needed 🙏
# 🔄 Affinity (photo, design etc.)- Affinity
# ----------- WINDOW-MANAGER -------------
# ✅ Blurred - Brew
# ✅ Alt-tab - Brew
# ✅ Raycast - Nixpkgs
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
      aldente.enable = true;
      karabiner.enable = true;
      better-touch-tool.enable = true;
    };
    windowManager = {
      raycast.enable = true;
      altTab.enable = true;
      blurred.enable = true;
    };
    development = {
      orbstack.enable = true;
    };
  };

  shared.apps = {
    system = {
      insync.enable = true;
    };
    internet = {
      telegram.enable = true;
      slack.enable = true;
      discord.enable = true;
      protonmail-bridge.enable = true;
    };
    development = {
      postman.enable = true;
      docker.enable = false;
      antigravity.enable = true;
    };
  };
}
