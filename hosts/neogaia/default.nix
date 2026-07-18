{ ... }:
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

  # Swap is RAM-backed zram rather than an on-disk partition. Task 0003 lifts
  # this into the zram toggle Module; enabled directly here for now.
  zramSwap.enable = true;
}
