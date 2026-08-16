{ config, pkgs, lib, inputs, ... }:
# astoria hardware — Dell XPS 13 9300 (i7-1065G7 Ice Lake, 4K UHD+, 16 GB).
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
  # Keys: `sbctl create-keys` at install, `enroll-keys --microsoft` at first boot (README Phase 3/4b).
  boot.loader.systemd-boot.enable = lib.mkForce false;  # Lanzaboote sets boot.loader.external.enable = true
  boot.loader.efi.canTouchEfiVariables = true;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 30;
  };

  # --- Kernel ---
  boot.kernelPackages = pkgs.linuxPackages;
  # S3 + Secure Boot breaks suspend on the 9300; mkAfter overrides nixos-hardware's
  # `mem_sleep_default=deep` (kernel is last-wins for this param).
  boot.kernelParams = lib.mkMerge [
    [ "resume=/dev/mapper/luks-swap" ]                # matches disko mapper (see §disko)
    (lib.mkAfter [ "mem_sleep_default=s2idle" ])
  ];

  # --- Initrd (systemd stage 1) ---
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [
    "xhci_pci" "thunderbolt" "vmd" "nvme" "usb_storage" "sd_mod"
  ];
  # Readable LUKS prompt on the 4K panel.
  console.earlySetup = true;
  console.font = "ter-v32b";
  console.packages = [ pkgs.terminus_font ];

  # --- LUKS: cryptroot = passphrase, cryptswap = TPM auto-unlock ---
  # TPM keyslot enrolled post-install via systemd-cryptenroll (README Phase 4c).
  boot.initrd.luks.devices."luks-swap" = {
    crypttabExtraOpts = [ "tpm2-device=auto" ];
  };

  # --- Wi-Fi (AX201 iwlwifi) ---
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
  # Charge thresholds silently fail with a BIOS admin password set — keep it unset (README Phase 2).
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT   = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC  = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_SAV = "power";
      CPU_BOOST_ON_BAT              = 0;
      CPU_BOOST_ON_AC               = 1;
      CPU_HWP_DYN_BOOST_ON_BAT      = 0;
      PLATFORM_PROFILE_ON_BAT       = "cool";
      PLATFORM_PROFILE_ON_SAV       = "quiet";
      INTEL_GPU_MIN_FREQ_ON_BAT     = 300;
      INTEL_GPU_MAX_FREQ_ON_BAT     = 750;
      INTEL_GPU_BOOST_FREQ_ON_BAT   = 750;
      RUNTIME_PM_ON_BAT             = "auto";
      PCIE_ASPM_ON_BAT              = "powersupersave";
      PCIE_ASPM_ON_SAV              = "powersupersave";
      WIFI_PWR_ON_BAT               = "off";
      START_CHARGE_THRESH_BAT0      = 60;
      STOP_CHARGE_THRESH_BAT0       = 80;
    };
  };
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
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "30min";
    SuspendState = "mem";
    # ACPI S4 (`platform`) silently no-ops on this firmware; `shutdown` + resume= works.
    HibernateMode = "shutdown";
  };

  # --- Graphics (no intel-compute-runtime — Gen 11 unsupported) ---
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  # --- Firmware ---
  services.fwupd.enable = true;
  hardware.enableAllFirmware = true;

  # --- Disk layout (disko) ---
  # disko owns `device`, `allowDiscards`, and the generated initrd LUKS entries — don't redeclare.
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
