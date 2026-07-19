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

- [ ] The `Host`'s disk layout declares a 2 GiB EFI system partition
- [ ] Every local branch worth keeping exists on the remote before the disk is erased
- [ ] The reimage is performed from a configuration carrying the hardware profile, following the existing install documentation
- [ ] The install documentation is corrected wherever the procedure diverged from what it describes
- [ ] Manual confirmation: the machine boots, the encrypted root unlocks, and console login succeeds
- [ ] Manual confirmation: reported free space on the boot partition is consistent with its 2 GiB size, resolving the discrepancy observed before the reimage — where a 512 MiB partition reported 1022 MiB
- [ ] The project's agent instructions record that a flake only sees git-tracked files, so an untracked file is invisible to evaluation
