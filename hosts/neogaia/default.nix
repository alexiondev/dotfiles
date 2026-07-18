{ ... }:
# neogaia — Dell XPS 13 9380 laptop.
#
# The filesystems and hardware profile below are placeholder values, not the
# machine's real encrypted layout.
{
  imports = [ ./hardware-configuration.nix ];

  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Placeholder label-based filesystems.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };
}
