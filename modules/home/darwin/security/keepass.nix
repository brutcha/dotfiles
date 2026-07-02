{ config, pkgs, lib, ... }:
#
# KeePassXC password manager
#
# Available options:
# - home.apps.security.keepass.enable - Install KeePassXC, configure browser integration
#
# Browser integration: install the KeePassXC-Browser extension in the
# browser (Helium uses the same .crx as Chromium-family). The native
# messaging manifest below is dropped at Helium's path; for other
# browsers, KeePassXC writes its own manifest from Settings → Browser
# Integration.
# One-time UI step per kdbx: Database → Database Settings → Browser
# Integration → "Allow KeePassXC-Browser to access this database". That
# flag lives inside the encrypted kdbx; nix can't set it.
#
let
  cfg = config.home.apps.security.keepass;

  chromeExtensionId = "oboonakemofpalcgghocfoadofidjkkk";
  keepassxcProxy = "${pkgs.keepassxc}/Applications/KeePassXC.app/Contents/MacOS/keepassxc-proxy";
  nativeMessagingManifest = builtins.toJSON {
    name = "org.keepassxc.keepassxc_browser";
    description = "KeePassXC integration with native messaging support";
    path = keepassxcProxy;
    type = "stdio";
    allowed_origins = [ "chrome-extension://${chromeExtensionId}/" ];
  };

  # programs.keepassxc.settings is NOT used — home-manager would symlink
  # keepassxc.ini into the read-only nix store and block UI saves
  # (https://github.com/nix-community/home-manager/issues/8257).
  # crudini merges keys into a writable INI on rebuild; UI changes to
  # untouched keys persist between rebuilds.
  browserSettings = {
    Enabled              = true;     # start browser integration socket
    UpdateBinaryPath     = false;    # don't overwrite our manifest paths
    AlwaysAllowAccess    = true;     # suppress per-entry access dialog
    AlwaysAllowUpdate    = true;     # suppress per-entry update dialog
    AllowExpiredCredentials = true;
    SearchInAllDatabases = true;
    ShowNotification     = true;
    HideWindow           = false;
    UseCustomProxy       = false;
    SupportBrowserProxy  = true;
  };

  iniMergeCommands = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v:
      let
        strVal = if builtins.isBool v then (if v then "true" else "false") else toString v;
      in
      "      $DRY_RUN_CMD ${pkgs.crudini}/bin/crudini --set \"$configPath\" Browser ${k} ${strVal}"
    ) browserSettings
  );
in
{
  options.home.apps.security.keepass.enable =
    lib.mkEnableOption "KeePassXC + browser integration";

  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkMerge [
    (lib.mkIf cfg.enable {
      programs.keepassxc.enable = true;

      home.activation.keepassxcSettings =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          configPath="$HOME/Library/Application Support/KeePassXC/keepassxc.ini"
          $DRY_RUN_CMD mkdir -p "$(dirname "$configPath")"
          if [ -L "$configPath" ]; then
            $DRY_RUN_CMD rm "$configPath"
          fi
          $DRY_RUN_CMD touch "$configPath"
${iniMergeCommands}
        '';
    })

    # Helium native messaging manifest only when Helium is also enabled.
    (lib.mkIf (cfg.enable && config.home.apps.internet.helium.enable) {
      home.file."Library/Application Support/net.imput.helium/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json".text =
        nativeMessagingManifest;
    })
  ]);
}
