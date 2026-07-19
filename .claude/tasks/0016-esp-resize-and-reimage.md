---
blocked-by: 0013-nixos-hardware-profile
---

## What to build

Grow `neogaia`'s EFI system partition and reimage the laptop from the finished configuration.

The partition is 512 MiB today, holding about seven generations at roughly 70 MiB of kernel and initrd apiece, and this `Host` runs a large third-party kernel. It grows to 2 GiB, which holds around 28 — comfortably past the 15 that are retained, at a cost of 0.3% of a 512 GB disk.

It cannot be grown in place: it sits first on the disk, starting at sector 2048 with the encrypted container immediately behind it, so enlarging it means moving that container's start offset. An encrypted volume's start cannot be relocated without rewriting its entire payload, which here is over 500 GiB. A reimage is the only practical route, and it is cheapest now — the machine is days old and holds around 3 GiB, of which 136 MiB is user data.

The hardware profile blocks this because it is the one boot-affecting change queued: it adds a kernel parameter and blacklists a module. Proving it boots while a known-good generation still exists to roll back to means the reimage installs a configuration already known to work on this hardware. A freshly imaged machine has one generation and no rollback target, which is the wrong place to discover a bad kernel parameter.

Nothing else blocks it. The housekeeping and commit-identity changes carry no boot risk and apply in seconds on either side of the wipe, so they must not be allowed to delay it — the case for reimaging now rests on the machine still holding almost nothing, and that erodes with every day of use.

This reimage is also the reproducibility test of the install documentation. The first install was performed while writing it; performing it a second time against the current configuration is what proves it is a procedure rather than a record of one improvised session.

One thing must be true before the disk is erased: every branch worth keeping has to exist on the remote, because work that lives only on this disk dies with it.

## Acceptance criteria

- [x] The `Host`'s disk layout declares a 2 GiB EFI system partition
- [x] Every local branch worth keeping exists on the remote before the disk is erased
- [x] The reimage is performed from a configuration carrying the hardware profile, following the existing install documentation
- [x] The install documentation is corrected wherever the procedure diverged from what it describes
- [x] Manual confirmation: the machine boots, the encrypted root unlocks, and console login succeeds
- [x] Manual confirmation: reported free space on the boot partition is consistent with its 2 GiB size, resolving the discrepancy observed before the reimage — where a 512 MiB partition reported 1022 MiB
- [x] The project's agent instructions record that a flake only sees git-tracked files, so an untracked file is invisible to evaluation

## Implementation Notes

Done. The reimage was performed by the operator and the machine now runs the
configuration this repository declares.

The install ran clean: the operator reports no step diverged from
`docs/install.md`, so criterion 4 is satisfied with no further corrections. The
four corrections that landed earlier came from reading the procedure; the run
itself found nothing to add. That is the reproducibility evidence the task was
after — the document is a procedure, not a record of one improvised session.

Verified on the running machine rather than assumed:

- `/dev/nvme0n1p1` is 2.0 GiB and `df` reports 2.0 GiB. The pre-reimage
  discrepancy, where a 512 MiB partition reported 1022 MiB, is gone.
- The hardware profile is live — `mem_sleep_default=deep` is on the kernel
  command line and `psmouse` is blacklisted and not loaded.
- `cryptroot` is open on `nvme0n1p2` with btrfs mounted, reached through a
  console login, so the boot-unlock-login path is exercised end to end.
- One generation exists (`system-1-link`), confirming a fresh install rather
  than a rebuild of the prior system.

The ordering hazard closed favourably: the declaration and the install landed
close enough together that the repository never asserted a layout the disk
lacked for long.

Two items outside the repo did not survive the wipe, as anticipated, and neither
is covered by a criterion: the wifi credentials, and the agent memory directory
— confirmed empty after the reimage.
