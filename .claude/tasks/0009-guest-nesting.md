---
spec: guests
blocked-by: 0002-guest-walking-skeleton
---

## What to build

The Host-side placement that makes the OCI fallback a plain Guest, so image-only software has a declarative home without a separate mechanism.
A Host sets `nesting` to grant the nested-container prerequisites so the Guest's interior can run Podman and other OCI containers.
The Skeleton emits the nested-container cgroup-delegation and capability prerequisites once, so the operator flips one boolean and the interior's `oci-containers` runtime works, with Podman as the default runtime.

## Acceptance criteria

- [x] A Host setting `guests.<path>.nesting` grants the nested-container cgroup-delegation and capability prerequisites, off by default.
- [x] With `nesting` on, the Guest's interior can define `oci-containers` running Podman as the default runtime.
- [x] With `nesting` off, those prerequisites are absent and the Guest is unaffected.
- [x] A Host with a nesting Guest that defines an OCI container builds via `nix flake check`.

## Implementation Notes

- `nesting` is a Host-side placement field on the guest, a bool defaulting off, alongside the other placement fields in `lib.nix`.
On, it grants the guest's container `CAP_NET_ADMIN` and the `/dev/net/tun` and `/dev/fuse` device nodes, the capability and devices an OCI runtime reaches for to network its containers and back their overlay storage.
Off, both `additionalCapabilities` and `allowedDevices` are empty, matching the NixOS defaults, so a non-nesting guest is untouched.

- The capability prerequisite is `CAP_NET_ADMIN` alone.
A container-backend guest runs privileged (`privateUsers = "no"`), so it already retains the broad nspawn capability set including `CAP_SYS_ADMIN`; the one addition an OCI runtime needs is network administration for its bridges and firewall rules.

- cgroup delegation is not toggled by `nesting`, a deliberate deviation from the criterion's wording that the flag "grants" it and that it is "absent" when off.
The NixOS container backend sets `Delegate = true` on every container's unit unconditionally, so the delegated cgroup subtree an OCI runtime manages is always present.
Re-emitting it under `nesting` would be redundant, and forcing it off for non-nesting guests to make it literally "absent" would remove a harmless, useful default for no gain.
The Skeleton records the prerequisite as satisfied-elsewhere with an absence pointer comment, so a reader does not think delegation was forgotten.

- A new `guests/nesting-sample.nix` carries an interior that defines an `oci-containers` workload, the payload the criteria exercise, and `neogaia` enables it with `nesting = true`.
This follows the walking-skeleton's precedent of proving a guest path through the one Host's `nix flake check`: the flake check builds the nested `nixos-system-nesting-sample` in full, pulling in `podman` and the generated `podman-hello.service` unit, which is how criteria two and four are verified on the build seam.
The sample carries the same modest caps as the walking-skeleton guest so an interior container cannot starve the laptop.

- The two behaviors the build seam cannot prove — that the interior Podman actually starts a container and that its networking works — are left to manual verification on the target Host and to the VM integration test of task 0010, per the spec's testing decisions.
