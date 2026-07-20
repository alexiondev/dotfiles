## What to build

Bound the three things on this machine that currently grow without any limit: the Nix store, the set of retained system generations, and the boot menu.

Garbage collection runs weekly, deleting generations older than 30 days. That window is the point of the setting — on a rolling channel with a third-party kernel, the value of an old generation is having a known-good system to boot when an update breaks something, and disk space is not scarce here: the store is under 5 GiB against 473 GiB free.

Store optimisation runs weekly on its own schedule rather than at build time, so deduplication never adds latency to a rebuild.

Retained boot configurations are capped at 15. Each generation stores a kernel and an initrd on the EFI system partition at roughly 70 MiB apiece, and that partition is small and fixed. An exhausted one fails at bootloader installation — after the build has already succeeded, which is a confusing place to get stuck. The cap assumes the enlarged partition; on the current 512 MiB one only about seven fit.

## Acceptance criteria

- [x] Automatic garbage collection is enabled weekly, deleting generations older than 30 days
- [x] Store optimisation is scheduled weekly, rather than performed at build time
- [x] Retained boot configurations are capped at 15
- [x] These are declared as plumbing in the shared base config, so every future `Host` inherits them
- [x] `nix flake check` builds the `neogaia` toplevel
- [x] Manual confirmation after a rebuild: the collection and optimisation timers exist and are scheduled

## Implementation Notes

The two schedules are named days rather than the bare `weekly` keyword.
systemd expands `weekly` to `Mon *-*-* 00:00:00`, which would have started collection and deduplication at the same instant every week, leaving `nix-optimise` hard-linking paths `nix-gc` was concurrently deleting.
Collection now runs `Mon 03:15` and optimisation `Thu 03:45`, which keeps both weekly and keeps them apart.

The boot configuration cap sits in the shared base as the task asks, and is inert rather than an error on a host that does not use systemd-boot.
A future host on another bootloader therefore inherits no cap, which is the one place the "every future host inherits them" promise does not reach.

Confirmed on `neogaia` after a switch: `systemctl list-timers 'nix-*'` lists both units, `nix-optimise` next on Thursday and `nix-gc` next on Monday, each `Persistent=true` so a suspended laptop catches up on a missed firing.
`/boot` reports 2 GiB with 113 MiB used, so the cap of 15 sits against the enlarged partition it assumes.
