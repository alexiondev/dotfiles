{ ... }:
# neogaia's disk layout, declared with disko and interpreted by the disko module
# the host-builder wires in. This is a per-Host concern: another Host declares a
# different `disko.devices` (or none, preserving an existing pool by importing it).
#
# One NVMe disk, GPT: an EFI system partition for systemd-boot, and a LUKS
# container holding a btrfs filesystem with subvolumes. Swap is zram (RAM-backed),
# so there is deliberately no on-disk swap partition. disko derives the matching
# `fileSystems.*` and `boot.initrd.luks.devices.*` from this, so a normal boot
# prompts for the passphrase in the initrd and unlocks the encrypted root.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
