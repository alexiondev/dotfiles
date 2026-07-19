## What to build

Bound the three things on this machine that currently grow without any limit: the Nix store, the set of retained system generations, and the boot menu.

Garbage collection runs weekly, deleting generations older than 30 days. That window is the point of the setting — on a rolling channel with a third-party kernel, the value of an old generation is having a known-good system to boot when an update breaks something, and disk space is not scarce here: the store is under 5 GiB against 473 GiB free.

Store optimisation runs weekly on its own schedule rather than at build time, so deduplication never adds latency to a rebuild.

Retained boot configurations are capped at 15. Each generation stores a kernel and an initrd on the EFI system partition at roughly 70 MiB apiece, and that partition is small and fixed. An exhausted one fails at bootloader installation — after the build has already succeeded, which is a confusing place to get stuck. The cap assumes the enlarged partition; on the current 512 MiB one only about seven fit.

## Acceptance criteria

- [ ] Automatic garbage collection is enabled weekly, deleting generations older than 30 days
- [ ] Store optimisation is scheduled weekly, rather than performed at build time
- [ ] Retained boot configurations are capped at 15
- [ ] These are declared as plumbing in the shared base config, so every future `Host` inherits them
- [ ] `nix flake check` builds the `neogaia` toplevel
- [ ] Manual confirmation after a rebuild: the collection and optimisation timers exist and are scheduled
