---
blocked-by: 0016-esp-resize-and-reimage
---

## What to build

Replace `neogaia`'s hand-written hardware detection file with a real scan of the machine it describes.

The file was written before the laptop ran NixOS, as an educated guess at what a Dell XPS 13 9380 needs, and still says so. The guess turned out to be adequate — the module required to reach the encrypted root is present and working — so this is honesty maintenance rather than a fix. It matters because the next person to read the file, including a future reader of this repo, should be able to trust that it describes measured hardware.

Only the detection results are kept: the modules the initrd needs, the modules the kernel loads, and the platform. The generated output also contains filesystem and swap declarations, which are dropped — the declarative disk layout owns those, produces them on every evaluation, and a second stale definition would either conflict outright or silently disagree.

Generating the scan requires root on the target machine.

## Acceptance criteria

- [ ] The detection file's contents come from a scan of the running machine rather than a guess
- [ ] Filesystem and swap declarations are absent from it, leaving the disk layout as the sole source of those
- [ ] The file no longer describes itself as a placeholder, and says plainly what it holds
- [ ] `nix flake check` builds the `neogaia` toplevel
