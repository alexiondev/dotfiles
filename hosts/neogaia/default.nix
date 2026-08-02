{
  config,
  inputs,
  pkgs,
  ...
}:
# neogaia — Dell XPS 13 9380 laptop.
# Disk layout is in ./disk.nix.
# `fileSystems` are derived from it, none declared here.
{
  imports = [
    inputs.nixos-hardware.nixosModules.dell-xps-13-9380
    ./hardware-configuration.nix
    ./disk.nix
  ];

  system.stateVersion = "26.05";

  # systemd-boot on the EFI system partition.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # Redistributable firmware for the QCA6174 wifi (ath10k blobs).
  # Intel microcode updates follow from this, so none is declared here.
  hardware.enableRedistributableFirmware = true;

  # RAM-backed swap, no on-disk swap partition.
  zramSwap.enable = true;

  # So wifi can be joined from the console.
  networking.networkmanager.enable = true;

  # So setup can be driven over the network.
  # The matching host public keys sit beside this file in plaintext, since
  # publishing them is their purpose.
  modules.ssh.enable = true;
  modules.ssh.hostKeys.sopsFile = ../../secrets/neogaia.yaml;
  modules.ssh.userKey.sopsFile = ../../secrets/neogaia.yaml;

  # A machine the operator works from, so it admits the workstation keys alone.
  modules.ssh.authorizedKeys = config.modules.ssh.workstationKeys;

  modules.toolkit.enable = true;

  # The walking-skeleton guest, enabled like any module: proves the guest path
  # end to end through this host's `nix flake check`.
  # Modest caps keep the skeleton guest from starving the laptop.
  guests.sample.enable = true;
  guests.sample.limits = {
    memory = "1G";
    cpu = "100%";
    tasksMax = 512;
  };

  # The nesting guest, run with `nesting` on: proves an interior OCI container
  # on Podman builds end to end through this host's `nix flake check`.
  guests.nesting-sample.enable = true;
  guests.nesting-sample.nesting = true;
  guests.nesting-sample.limits = {
    memory = "1G";
    cpu = "100%";
    tasksMax = 512;
  };

  modules.agents.claude-code.enable = true;
  modules.agents.herdr.enable = true;
  modules.agents.tools.gitea-axi.enable = true;
  modules.agents.pi.enable = true;
  modules.agents.pi.subagents.maxConcurrent = 8;

  modules.desktop.enable = true;
  modules.desktop.obsidian.enable = true;
  modules.desktop.steam.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_GB.UTF-8";
}
