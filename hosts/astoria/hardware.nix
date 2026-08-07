{ config, pkgs, lib, inputs, ... }:
#
# astoria hardware — Dell XPS 13 9300 (i7-1065G7 Ice Lake, 4K UHD+, 16 GB).
#
# Bootloader (Lanzaboote + Secure Boot), kernel + initrd + LUKS + resume,
# Wi-Fi, Bluetooth, TLP, thermal, sleep/hibernate, hardware.graphics,
# firmware, and the disko partition config inlined at the bottom.
#
{
  imports = [
    # https://github.com/NixOS/nixos-hardware/tree/master/dell/xps/13-9300
    inputs.nixos-hardware.nixosModules.dell-xps-13-9300  # psmouse blacklist + i2c-designware sleep-resume + QCA6390 fw
    # https://github.com/nix-community/disko
    inputs.disko.nixosModules.disko
    # https://github.com/nix-community/lanzaboote
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  # --- Bootloader (Lanzaboote / Secure Boot) ---
  # Two-step key lifecycle (README Phase 3 step 4 + Phase 4b step 2):
  # `sbctl create-keys` at install time → local keypair under pkiBundle;
  # `sbctl enroll-keys --microsoft` at first boot → enroll into UEFI while
  # in Setup Mode. --microsoft appends MS certs to KEK+db only (PK stays
  # under our key), so signed option ROMs still load.
  boot.loader.systemd-boot.enable = lib.mkForce false;  # Lanzaboote sets boot.loader.external.enable = true
  boot.loader.efi.canTouchEfiVariables = true;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 30;
  };

  # --- Kernel ---
  boot.kernelPackages = pkgs.linuxPackages;
  # nixos-hardware appends `mem_sleep_default=deep` unconditionally, but this
  # box's firmware is s2idle-only → `systemctl suspend` returns -EINVAL.
  # Kernel is last-wins for `mem_sleep_default=`, so `mkAfter` overrides.
  # `mkMerge` (not two `boot.kernelParams = [...]` — Nix parser rejects
  # duplicate attr paths before eval, so `mkAfter` on a second decl doesn't
  # rescue it).
  boot.kernelParams = lib.mkMerge [
    [ "resume=/dev/mapper/luks-swap" ]                # matches disko mapper (see §disko)
    (lib.mkAfter [ "mem_sleep_default=s2idle" ])
  ];

  # --- Initrd (systemd stage 1) ---
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [
    # No microSD reader on the 9300 (dropped after 9370). sd_mod stays —
    # usb_storage routes external USB via SCSI.
    "xhci_pci" "thunderbolt" "vmd" "nvme" "usb_storage" "sd_mod"
  ];
  # 3840x2400 framebuffer text at ~6pt is unreadable at the LUKS prompt.
  console.earlySetup = true;
  console.font = "ter-v32b";
  console.packages = [ pkgs.terminus_font ];

  # --- LUKS: cryptroot = passphrase, cryptswap = TPM auto-unlock ---
  # `device` + `allowDiscards` come from disko; only the additive TPM opt
  # goes here (list-merge). TPM keyslot enrolled post-install via
  # `systemd-cryptenroll` (README Phase 4c); passphrase set at disko time
  # remains as fallback.
  boot.initrd.luks.devices."luks-swap" = {
    crypttabExtraOpts = [ "tpm2-device=auto" ];
  };

  # --- Wi-Fi (AX201 iwlwifi tuning, confirmed via lspci -nn / dmesg) ---
  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
  '';
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  networking.networkmanager.wifi.backend = "wpa_supplicant";

  # --- Bluetooth ---
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;
  services.blueman.enable = true;

  # --- Power ---
  services.power-profiles-daemon.enable = false;   # TLP owns this
  # https://linrunner.de/tlp/
  # TLP's Dell plugin writes `charge_types = Custom` via dell-smbios; that
  # write silently fails when a BIOS admin password is set → thresholds
  # never take effect. Keep BIOS admin password UNSET (README Phase 2).
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT   = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC  = "balance_performance";
      CPU_BOOST_ON_BAT              = 0;
      CPU_BOOST_ON_AC               = 1;
      CPU_HWP_DYN_BOOST_ON_BAT      = 0;
      # Silent no-op if /sys/firmware/acpi/platform_profile_choices is empty
      # (verify-hardware.sh reports).
      PLATFORM_PROFILE_ON_BAT       = "cool";
      INTEL_GPU_MIN_FREQ_ON_BAT     = 100;
      INTEL_GPU_MAX_FREQ_ON_BAT     = 750;
      RUNTIME_PM_ON_BAT             = "auto";
      PCIE_ASPM_ON_BAT              = "powersupersave";
      WIFI_PWR_ON_BAT               = "off";
      START_CHARGE_THRESH_BAT0      = 60;
      STOP_CHARGE_THRESH_BAT0       = 80;
    };
  };
  # nixos-hardware/dell/xps/13-9300 already mkDefault-enables thermald and
  # fwupd; explicit `true` here for intent clarity (no-op override).
  services.thermald.enable = true;
  # https://github.com/erpalma/throttled — clears BIOS PL1/PL2 override on Ice Lake
  services.throttled.enable = true;

  # --- Lid / suspend: suspend-then-hibernate (30 min) ---
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "suspend-then-hibernate";
  };
  # 26.11 removed `systemd.sleep.extraConfig` (mkRemovedOptionModule); attrs
  # under `.settings.Sleep` become sleep.conf keys verbatim.
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "30min";
    SuspendState = "mem";
    HibernateMode = "platform";
  };

  # --- Graphics ---
  # intel-compute-runtime meta says "12th Gen and newer" — Gen 11 unsupported.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  # --- Firmware ---
  services.fwupd.enable = true;
  hardware.enableAllFirmware = true;

  # --- Disk layout (disko, declarative) ---
  # Inlined here so all HW-topology declarations live in one file. `device`
  # on each LUKS entry, `allowDiscards`, and the auto-generated
  # `boot.initrd.luks.devices.<name>` entries come from disko — setting
  # them again in boot.initrd.luks would conflict.
  disko.devices.disk.main = {
    device = "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "4G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        cryptswap = {
          size = "20G";
          label = "cryptswap";
          content = {
            type = "luks";
            name = "luks-swap";              # matches boot.initrd.luks.devices.luks-swap + resume=
            settings.allowDiscards = true;
            content.type = "swap";
          };
        };
        cryptroot = {
          size = "100%";                     # auto-priority 9001 → placed last
          label = "cryptroot";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-L" "nixos" "-f" ];
              subvolumes = {
                "@root"      = { mountpoint = "/";           mountOptions = [ "compress=zstd:1" "noatime" ]; };
                "@nix"       = { mountpoint = "/nix";        mountOptions = [ "compress=zstd:1" "noatime" ]; };
                "@home"      = { mountpoint = "/home";       mountOptions = [ "compress=zstd:1" "noatime" ]; };
                "@snapshots" = { mountpoint = "/.snapshots"; mountOptions = [ "compress=zstd:1" "noatime" ]; };
              };
            };
          };
        };
      };
    };
  };
}
