{
  config,
  pkgs,
  ...
}:
# pikachu — AZW ME Pro server.
# Disk layout is in ./disk.nix.
# `fileSystems` for the root disk are derived from it.
{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
  ];

  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  zramSwap.enable = true;

  systemd.network = {
    enable = true;
    networks."10-uplink" = {
      matchConfig.MACAddress = "78:55:36:07:af:49";
      networkConfig.DHCP = "yes";
      linkConfig.RequiredForOnline = "routable";
    };
  };
  networking.useDHCP = false;

  boot.zfs.forceImportRoot = false;

  modules.zfs = {
    enable = true;
    hostId = "2346edbd";
    pools.pikachu = { };
  };

  modules.ssh.enable = true;
  modules.ssh.hostKeys.restore = false;
  modules.ssh.authorizedKeys = config.modules.ssh.workstationKeys;

  modules.git.enable = true;
  modules.toolkit.enable = true;

  environment.systemPackages = with pkgs; [
    pciutils
    smartmontools
    usbutils
  ];

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_GB.UTF-8";
}
