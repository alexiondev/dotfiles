{ pkgs, ... }:
# neogaia — Dell XPS 13 9380 laptop.
#
# The disk layout lives in ./disk.nix (disko); the resulting `fileSystems` are
# derived from it, so none are declared by hand here.
{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
  ];

  system.stateVersion = "26.05";

  # systemd-boot on the EFI system partition disko creates. The initrd prompts
  # for the LUKS passphrase (disko wires up boot.initrd.luks.devices), so a
  # normal boot unlocks the encrypted root.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # neogaia runs the CachyOS kernel, selected per-Host via boot.kernelPackages.
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # Intel CPU microcode updates for the XPS 13's Core i7-8565U.
  hardware.cpu.intel.updateMicrocode = true;

  # Redistributable firmware — carries the ath10k blobs the QCA6174 wifi needs.
  hardware.enableRedistributableFirmware = true;

  # Swap is RAM-backed zram rather than an on-disk partition.
  zramSwap.enable = true;

  # NetworkManager drives the wifi so it can be joined from the console.
  networking.networkmanager.enable = true;

  # An SSH daemon so the rest of the setup can be driven over the network.
  services.openssh.enable = true;

  # fish as the login shell.
  modules.fish.enable = true;
  modules.fish.defaultShell = true;

  # tmux as the terminal multiplexer.
  modules.tmux.enable = true;

  # Neovim, configured declaratively via nixvim.
  modules.nvim.enable = true;

  # Claude Code, Anthropic's CLI, installed via home-manager.
  modules.claude-code.enable = true;

  # Locale preferences for the base system.
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "us";
}
