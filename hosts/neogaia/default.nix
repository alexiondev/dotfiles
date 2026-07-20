{ inputs, pkgs, ... }:
# neogaia — Dell XPS 13 9380 laptop.
# Disk layout is in ./disk.nix; `fileSystems` are derived from it, none declared here.
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
  # Intel microcode updates follow from this; none declared here.
  hardware.enableRedistributableFirmware = true;

  # RAM-backed swap; no on-disk swap partition.
  zramSwap.enable = true;

  # So wifi can be joined from the console.
  networking.networkmanager.enable = true;

  # So setup can be driven over the network.
  # The matching host public keys sit beside this file in plaintext, since
  # publishing them is their purpose.
  modules.ssh.enable = true;
  modules.ssh.hostKeys.sopsFile = ../../secrets/neogaia.yaml;

  # fish as the login shell.
  modules.fish.enable = true;
  modules.fish.defaultShell = true;

  modules.tmux.enable = true;
  modules.nvim.enable = true;
  modules.claude-code.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_GB.UTF-8";
}
