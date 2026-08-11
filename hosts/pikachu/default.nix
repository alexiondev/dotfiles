{ pkgs, ... }:
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
    netdevs = {
      "40-br-vlan20".netdevConfig = {
        Name = "br-vlan20";
        Kind = "bridge";
      };
      "40-vlan20" = {
        netdevConfig = {
          Name = "vlan20";
          Kind = "vlan";
        };
        vlanConfig.Id = 20;
      };
    };

    networks = {
      "10-uplink" = {
        matchConfig = {
          Name = "enp2s0";
          MACAddress = "78:55:36:07:af:49";
        };
        networkConfig.DHCP = "yes";
        vlan = [ "vlan20" ];
        linkConfig.RequiredForOnline = "routable";
      };
      "40-vlan20" = {
        matchConfig.Name = "vlan20";
        networkConfig.Bridge = "br-vlan20";
        linkConfig.RequiredForOnline = "no";
      };
      "40-br-vlan20" = {
        matchConfig.Name = "br-vlan20";
        linkConfig.RequiredForOnline = "no";
      };
    };
  };
  networking.useDHCP = false;

  modules.network.vlans = [ 20 ];

  boot.zfs.forceImportRoot = false;

  modules.zfs = {
    enable = true;
    hostId = "2346edbd";
    pools.pikachu = { };
  };

  modules.ssh.enable = true;
  modules.ssh.hostKeys.sopsFile = ../../secrets/pikachu.yaml;
  modules.ssh.userKey.sopsFile = ../../secrets/pikachu.yaml;

  modules.git.enable = true;
  modules.toolkit.enable = true;

  guests.actualbudget = {
    enable = true;
    vlan = 20;
    mac = "BC:24:11:C1:CD:28";
    dataPath = "/pikachu/data/actualbudget";
  };

  environment.systemPackages = with pkgs; [
    pciutils
    smartmontools
    usbutils
  ];

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_GB.UTF-8";
}
