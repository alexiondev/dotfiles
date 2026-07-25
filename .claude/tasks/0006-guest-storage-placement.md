---
spec: guests
blocked-by: [0002-guest-walking-skeleton, 0005-storage-zfs-foundation]
---

## What to build

The Host-side placement that lets a Guest mount shared pool paths at any granularity and write to them without permission errors.
A Host sets `mounts`, a map of guest path to host path, each with a per-mount `readOnly`, defaulting to read-write to match the migration reality that services must write to pools.
Each entry is realized as a bind mount of the nested container, so a Guest sees exactly the data it should — a single folder or a whole pool, read-only or read-write.
Because the container backend uses identity mapping, a guest service that writes as the shared `storage` group lands on the pool as that same group, which is the entire "no permission errors" mechanism and the privileged-container equivalent the operator already trusts from Proxmox.

## Acceptance criteria

- [x] A Host setting `guests.<path>.mounts` bind-mounts each host path at its guest path inside the nested container.
- [x] Each mount honours its per-mount `readOnly`, defaulting to read-write.
- [x] Identity mapping is configured so a guest service writing as the `storage` group lands on the host pool as that same group with no permission error.
- [x] A Host with a Guest that has pool mounts builds, and the resolved bind mounts are verifiable by `nix eval`. Verified by ad-hoc mounts on the sample guest; no host commits mounts (see notes).

## Implementation Notes

`mounts` is a placement option on the `guest` builder: an attribute set keyed by the guest-interior path, each value carrying `hostPath` and a `readOnly` flag that defaults to `false`.
It is realized as the nested container's `bindMounts`, where the container option's `mountPoint` defaults to the attribute key, so the guest path is stated once as the key.
The upstream `bindMounts` `isReadOnly` defaults to read-only, so it is driven explicitly from `readOnly` to make read-write the default here, matching the migration reality that services must write to their pools.

Identity mapping is pinned with `privateUsers = "no"`, which runs the container in the host's uid and gid space one to one.
That is the current NixOS default, but the option documents `"pick"` (a shifting map that would break pool writes) as its recommended value, so the property is pinned rather than left to a default that may drift.
With this mapping and the shared `storage` group from the storage foundation (identical gid on host and guest), a guest process writing as that group lands on a bind-mounted pool as the same group.
The write itself is verified manually on the target host per the spec's testing decisions, since a real identity-mapped ZFS write cannot be reproduced in the build.

No host commits pool mounts.
The repo's only host, `neogaia`, is a laptop with no ZFS pools, so a committed mount would point at a host path that does not exist and would fail the bind at container start.
This mirrors the storage and networking foundations (tasks 0005 and 0003), which verify by ad-hoc enablement rather than committing a placement a host cannot honestly carry.
The realization was verified through `nixosConfigurations.neogaia.extendModules`, setting two mounts on the sample guest: the resolved `containers.sample.bindMounts` carried the right `hostPath`, `mountPoint`, and per-mount `isReadOnly` (read-write and read-only), `privateUsers` resolved to `"no"`, the `storage` gid was identical on host and guest interior, and the full toplevel built.
`nix flake check` passes on the committed tree, where the sample guest declares no mounts.
