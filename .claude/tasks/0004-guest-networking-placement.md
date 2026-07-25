---
spec: guests
blocked-by: [0002-guest-walking-skeleton, 0003-network-vlan-foundation]
---

## What to build

The Host-side placement fields that make a Guest a first-class L2 citizen on a tagged VLAN, exactly as Proxmox did.
A Host sets `vlan`, and the Guest attaches to that Host's `br-vlan<id>` bridge by the naming convention, so the Guest states only which VLAN it lives on.
A Host may set `mac` to reuse an existing address so its router's DHCP reservations keep working; an unset `mac` derives a stable, readable address from the Guest's namespace path in a locally-administered range, surfaced via evaluation so the operator can add a reservation.
The MAC is pinned inside the guest through the guest's own systemd-networkd, which is the only way a nested-container MAC stays stable.
A Host may set `address` for a static IP; unset means DHCP, keeping IP management centralized at the router.
A build-time assertion ties the Guest's `vlan` to the set of VLANs its Host's `modules.network` declares, so a Guest naming an undeclared VLAN fails the Host build with a clear message rather than as a broken bridge at runtime.

## Acceptance criteria

- [x] A Host setting `guests.<path>.vlan` attaches the Guest to that Host's `br-vlan<id>` bridge by the naming convention.
- [x] Setting `mac` pins that exact address on the Guest via the guest's own systemd-networkd; leaving it unset derives a stable MAC from the Guest's namespace path in a locally-administered range, readable via `nix eval`.
- [x] Setting `address` gives the Guest a static IP on its VLAN; leaving it unset takes the address by DHCP.
- [x] A Guest whose `vlan` is not among its Host's declared VLANs fails `nix flake check` with a clear, actionable message naming the offending Guest and VLAN.
- [x] A Host with a correctly-placed networked Guest builds via `nix flake check`, and the Guest's resolved bridge attachment and derived MAC are verifiable by `nix eval`.

## Implementation Notes

The `br-vlan<id>` naming was a local helper in `modules/network.nix` and is now a shared `bridgeName` in `lib.nix`, exported through `my` and consumed by both the network foundation and guest placement.
The convention has one source, so the bridge a guest attaches to can never drift from the bridge the host emits.

The interior networking is realized by a small module injected into the guest's container config only when `vlan` is set.
It enables the guest's own systemd-networkd on `eth0` — the name a nested container gives its bridged veth — pinning the placement MAC there and taking the static `address` or DHCP when it is unset.
Pinning the MAC through the guest's own networkd is the only way a nested-container MAC stays stable; the nspawn-assigned veth MAC is otherwise regenerated.
Enabling networkd default-enables `systemd-resolved`, so a DHCP guest also gets its resolver.

The derived MAC is the `mac` option's default, so an unset MAC reads back through `nix eval .#nixosConfigurations.<host>.config.guests.<path>.mac`.
The first octet is `02` (locally-administered, unicast) and the remaining five octets are a hash slice of the namespace path.

A static `address` sets only the on-VLAN IP, with no gateway or DNS.
This mirrors `modules.network`, which deliberately dropped a `management.gateway` as speculative for the foundation slice; off-VLAN routing for a statically-addressed guest is a later concern, and the centralized path stays DHCP.

The networked path is verified by `nix eval` against `neogaia` through `extendModules` rather than by committing an enablement, exactly as task 0003 verified `modules.network`.
`neogaia` is a wifi laptop that cannot bridge, and enabling networkd on it would take over its DNS, so its committed `guests.sample` placement leaves `vlan` unset.
Verified: with `vlan = 10` the guest resolves `hostBridge = br-vlan10` and the interior `eth0` networkd pins the derived MAC; an unset `address` yields `DHCP = "yes"` and a set one yields the static CIDR; and `vlan = 99` against declared `[10 20]` fails the build with the actionable message.
`nix flake check` passes with `guests.sample` building its interior in full.
