---
blocked-by: 0016-esp-resize-and-reimage
---

## What to build

Replace `neogaia`'s hand-written hardware detection file with a real scan of the machine it describes.

The file was written before the laptop ran NixOS, as an educated guess at what a Dell XPS 13 9380 needs, and still says so. The guess turned out to be adequate — the module required to reach the encrypted root is present and working — so this is honesty maintenance rather than a fix. It matters because the next person to read the file, including a future reader of this repo, should be able to trust that it describes measured hardware.

Only the detection results are kept: the modules the initrd needs, the modules the kernel loads, and the platform. The generated output also contains filesystem and swap declarations, which are dropped — the declarative disk layout owns those, produces them on every evaluation, and a second stale definition would either conflict outright or silently disagree.

Generating the scan requires root on the target machine.

## Acceptance criteria

- [x] The detection file's contents come from a scan of the running machine rather than a guess
- [x] Filesystem and swap declarations are absent from it, leaving the disk layout as the sole source of those
- [x] The file no longer describes itself as a placeholder, and says plainly what it holds
- [x] `nix flake check` builds the `neogaia` toplevel

## Implementation Notes

**The guess was wider than the measurement, not narrower.**
It named `thunderbolt`, `usb_storage`, and `sd_mod`, none of which the scan reports; the scan adds `rtsx_pci_sdmmc` for the card reader.
Nothing needed to reach the root device was missing, so the guess was adequate as the task assumed, but it was not accurate.
`sd_mod` survives in the resolved list regardless, supplied by nixpkgs' own defaults; `thunderbolt` and `usb_storage` now genuinely go, and they matter only for booting from external media, which this machine does not do.

**Two further lines from the scan were dropped beyond the filesystem and swap declarations the task named.**
`boot.initrd.luks.devices."cryptroot".device` is derived by the disk layout, which the layout file already states, so keeping it would have created the same duplicate definition the task drops the filesystems to avoid.
`hardware.cpu.intel.updateMicrocode` falls outside the three things the task keeps, and the hardware profile supplies it anyway.
Both were checked rather than assumed: after the change the LUKS device, all four filesystems, and microcode all still resolve.

**The header was rewritten twice.**
Its first form enumerated the file's three attributes, which the repo's comment convention names as a feature inventory and forbids in a file-top header.
It now carries provenance and the absence pointer only.

**Not verified by a boot.**
`nix flake check` proves the configuration evaluates and builds, not that the initrd it produces can unlock LUKS and mount root.
Only a rebuild and reboot establishes that, with the previous generation available at the bootloader as the fallback.
