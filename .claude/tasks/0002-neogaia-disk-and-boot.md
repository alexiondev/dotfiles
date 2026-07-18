---
spec: laptop-mvi
blocked-by: 0001-skeleton-and-building-host
---

## What to build

Declare the `neogaia` laptop's disk with `disko` and make it unlock and boot on real hardware: a LUKS-encrypted btrfs volume with subvolumes plus zram swap, on an EFI system partition using systemd-boot, with the LUKS passphrase prompted at boot via the initrd.

The layout must build from the same tree as the `Host` toplevel (so the whole-`Host` build exercises it), and must be expressed as a per-`Host` disk concern so other machines can declare their own layouts later.

## Acceptance criteria

- [x] `neogaia` declares a `disko` layout: LUKS-encrypted btrfs with subvolumes plus zram swap on an EFI system partition.
- [x] systemd-boot is the bootloader; the initrd prompts for the LUKS passphrase so a normal boot unlocks the encrypted disk.
- [x] The `disko` layout builds as part of the `neogaia` toplevel build (no separate invocation needed to catch layout errors).
- [x] The disk layout is a per-`Host` concern, expressible differently for future `Host`s without restructuring the `Skeleton`.

## Implementation Notes

- **Layout.** One GPT disk at `/dev/nvme0n1`: a 512M EF00 ESP (vfat, `umask=0077`) mounted at `/boot`, and a 100%-fill LUKS partition (`cryptroot`, `allowDiscards`) holding a btrfs filesystem with three subvolumes — `@root` → `/`, `@home` → `/home`, `@nix` → `/nix` — each mounted `compress=zstd,noatime`.
  There is deliberately no on-disk swap partition; swap is RAM-backed zram.
- **Skeleton vs. per-Host split.** The disko *module* (`inputs.disko.nixosModules.disko`) is wired into the host-builder in `lib/default.nix`, so every `Host` can interpret a `disko.devices` declaration; the *layout itself* lives in `hosts/neogaia/disk.nix`.
  A future `Host` declares a different layout, or none at all (an undeclared `disko.devices` is a no-op), so servers that preserve an existing pool by import need no `Skeleton` change.
- **disko input follows nixpkgs.** Unlike chaotic (which must not), disko follows our `nixpkgs` so it builds against the same base.
- **Boot unlock.** disko's `type = "luks"` (no key file) generates `boot.initrd.luks.devices.cryptroot`, so the classic initrd prompts for the passphrase on a normal boot; the `nvme` initrd module was already present in `hardware-configuration.nix`.
- **zram enabled directly, not yet a Module.** Criterion 1 requires "plus zram swap," so `zramSwap.enable = true` is set on the `Host` now.
  Task 0003 owns the reusable zram toggle `Module` and will lift this line into it; the placeholder `fileSystems`/bootloader stubs from task 0001 are removed here since disko now derives `fileSystems`.
- **Verification.** `nix flake check` (the `checks.x86_64-linux.neogaia` toplevel) builds green.
  Confirmed via `nix eval`: disko-derived `fileSystems` = `/`,`/home`,`/nix` on btrfs `/dev/mapper/cryptroot` + `/boot` on the ESP; `boot.initrd.luks.devices` = `["cryptroot"]`; `systemd-boot.enable` and `zramSwap.enable` both true; `swapDevices` empty.
  The genuine end-to-end confirmation is the manual `disko-install` reimage, which is irreversible by nature and not automated.
