{ ... }:
# neogaia — Dell XPS 13 9380 laptop.
#
# Minimum viable Host: enough to evaluate and build the system toplevel. The
# real disk layout (disko: LUKS + btrfs + zram), the CachyOS kernel, networking,
# and the terminal Modules arrive in later tasks; the placeholders below are
# replaced by disko in task 0002.
{
  imports = [ ./hardware-configuration.nix ];

  system.stateVersion = "25.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Placeholder filesystems so the toplevel builds; superseded by the disko
  # layout in task 0002.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };
}
