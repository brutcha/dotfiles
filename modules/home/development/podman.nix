{ config, lib, pkgs, ... }:
#
# Podman + podman-compose (daemonless containers). Cross-platform: native on
# Linux (no VM), Lima/QEMU-backed VM on macOS via `podman machine`.
#
# Available options:
# - home.apps.development.podman.enable            - install podman + podman-compose
# - home.apps.development.podman.autoStartMachine  - launchd user agent for
#   `podman machine start` on macOS at login (default: true on darwin when
#   the module is enabled; irrelevant on Linux)
#
# One-time setup outside Nix on macOS: `podman machine init` (downloads a
# small Linux VM image). Subsequent reboots auto-start it via launchd.
#
let
  cfg = config.home.apps.development.podman;
in
{
  options.home.apps.development.podman = {
    enable = lib.mkEnableOption "Podman + podman-compose";

    autoStartMachine = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.hostPlatform.isDarwin;
      description = ''
        On macOS, install a launchd user agent that runs `podman machine start`
        at login so the container VM is up before any tool tries to spawn a
        container. Ignored on Linux (podman is native — no VM).
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = [
        pkgs.podman
        pkgs.podman-compose
      ];
    }

    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      # Point Docker-API clients (docker CLI, lazydocker, testcontainers, …)
      # at podman's user socket. $TMPDIR is per-user macOS DARWIN_USER_TEMP_DIR,
      # stable across reboots; ${TMPDIR%/} strips its trailing slash so the
      # scheme comes out as `unix:///abs/path` (docker-compliant).
      home.sessionVariables.DOCKER_HOST =
        "unix://\${TMPDIR%/}/podman/podman-machine-default-api.sock";
    })

    (lib.mkIf (cfg.autoStartMachine && pkgs.stdenv.hostPlatform.isDarwin) {
      launchd.agents.podman-machine-start = {
        enable = true;
        config = {
          Label = "org.dotfiles.podman-machine-start";
          ProgramArguments = [ "${pkgs.podman}/bin/podman" "machine" "start" ];
          RunAtLoad = true;
          # Not KeepAlive — `podman machine start` exits after the VM is up.
          # The VM itself is kept alive by podman's own supervision.
          StandardOutPath  = "${config.home.homeDirectory}/.local/state/podman-machine.log";
          StandardErrorPath = "${config.home.homeDirectory}/.local/state/podman-machine.log";
        };
      };
    })
  ]);
}
