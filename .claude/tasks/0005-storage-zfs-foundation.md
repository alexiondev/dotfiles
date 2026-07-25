---
spec: guests
blocked-by: 0002-guest-walking-skeleton
---

## What to build

The host-level pool-import foundation, `modules.zfs`, plus the shared `storage` group that makes identity-mapped pool writes work.
A Host declares its host id, the pools to import, and their dataset mountpoints; the pools are durable state that is imported, never rebuilt, so a service's data survives any rebuild or reimage.
A shared `storage` group with a fixed gid lives in the shared portion of the base config that both the host base and the guest-base include, giving 1:1 group ownership between a Host and its Guests.
This slice establishes the group and the pool import; a Guest actually writing to a mount as that group is the Guest storage placement slice.

## Acceptance criteria

- [x] `modules.zfs` declares an `enable` option and its option path mirrors its file location per the Namespace convention.
- [x] A Host declares its host id, its pools, and their dataset mountpoints; enabling the Module imports those pools rather than recreating them.
- [x] A shared `storage` group with a fixed gid is defined in the shared base and is present identically on both a Host and its Guests.
- [x] A Host enabling `modules.zfs` builds, and the `storage` gid is verifiable by `nix eval`. Verified by ad-hoc enablement on `neogaia`; the enablement is not committed (see notes).

## Implementation Notes

The pool import is realized by `boot.zfs.extraPools`, which imports the named pools rather than creating them, so a rebuild never touches pool contents.
`boot.supportedFilesystems = [ "zfs" ]` pulls the ZFS stack into the kernel and boot even on a host whose root is another filesystem, and `networking.hostId` is required because ZFS refuses to import a pool without a host id to stamp ownership onto.
Declared dataset mountpoints become plain `fileSystems` entries with `fsType = "zfs"`, orthogonal to the import: a pool with an empty map is still imported, leaving its datasets to their own ZFS `mountpoint` property.

`pools` is typed `attrsOf (attrsOf path)` — pool name to a dataset-relative-path to mountpoint map — rather than a per-pool submodule.
No per-pool option beyond the mount map is foreseen at host level, so the extra submodule layer would have been speculative.

The Module is `modules.zfs`, a flat single-file module, not `modules.storage.zfs` under a `storage/` directory.
Nothing else lives under a storage namespace, and the sibling host-level foundation `modules.network` is likewise flat, so the extra directory level would have grouped a single member.
The spec and ADR 0006 were updated to name it `modules.zfs` to match.

The `storage` group carries a fixed gid of 10000, placed in `base.nix` so a host and every guest built from this flake carry the identical number.
That identity is the whole write mechanism: an identity-mapped container write lands on the pool as the same numeric group with no per-service permission juggling.
10000 sits above the ids NixOS assigns automatically, so no generated account collides with it.
This slice only defines the group and the import; a Guest actually writing to a mount as this group is the Guest storage placement slice.

No host commits an enablement of this Module.
The repo's only host is `neogaia`, a laptop with a btrfs root, no ZFS pools, and a bleeding-edge CachyOS kernel whose `zfs-kernel-2.4.3` build is marked broken — so a committed ZFS enablement there would be both dishonest and unbuildable.
This mirrors the networking foundation's decision (task 0003) to verify by temporary enablement rather than commit one to a host that cannot honestly carry the feature.
The enabled build was verified through `nixosConfigurations.neogaia.extendModules`, enabling the Module against a declared pool and forcing `boot.kernelPackages = pkgs.linuxPackages` (a ZFS-supported kernel) so the incompatibility of *neogaia's* kernel choice does not mask the Module's own correctness; the full `nixos-system-neogaia` toplevel built.
The `storage` gid was verified identical (2000) on both the host config and the sample guest's interior, and `nix flake check` passes on the committed, module-inert tree.
The standing enablement waits for the first real storage host, supplied when that host is added.
