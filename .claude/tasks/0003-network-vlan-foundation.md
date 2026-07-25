---
spec: guests
---

## What to build

The host-level networking foundation, `modules.network`, that a Host declares once and every Guest attaches to.
A Host states its trunk interface and the set of VLANs to materialize, and the Module emits one bridge per tagged VLAN using systemd-networkd, named by the `br-vlan<id>` convention, and manages the Host's own management address.
This is a standalone host-level Module and does not yet wire any Guest to a bridge — that is the Guest networking placement slice.

## Acceptance criteria

- [x] `modules.network` declares an `enable` option and its option path mirrors its file location per the Namespace convention.
- [x] A Host declares its trunk interface and its set of VLAN ids through the Module's options.
- [x] Enabling the Module emits exactly one systemd-networkd bridge per declared VLAN, each named `br-vlan<id>`, and manages the Host's own management address.
- [x] A Host enabling `modules.network` builds via `nix flake check`, and the emitted bridge names are verifiable by `nix eval`. Verified by temporarily enabling it on `neogaia`; the enablement is not committed (see notes).

## Implementation Notes

Each VLAN materializes as three networkd entries: a `<trunk>.<id>` tagged sub-interface stacked on the trunk, a `br-vlan<id>` bridge, and a network enslaving the sub-interface to the bridge.
The trunk and every bridge set `RequiredForOnline = "no"`, so `systemd-networkd-wait-online` never blocks boot on a link with no carrier.

The management address takes a static CIDR, or DHCP when left null, on the management VLAN's bridge alone.
Two assertions guard it: the management VLAN must be one of the declared VLANs, and a declared management address must name a management VLAN, so an address can never be silently dropped for want of a bridge to carry it.

The Module owns its own NetworkManager `unmanaged` guard for the trunk, sub-interfaces, and bridges, so enabling it is self-sufficient on a host that also runs NetworkManager rather than pushing that wiring into every Host.
A `management.gateway` option was considered and dropped as speculative for this slice, since the foundation carries no other routing.

No host commits an enablement of this Module.
The repo's only host is `neogaia`, a wifi laptop on an access port, and enabling the Module there turns on `systemd-networkd` and pulls in `systemd-resolved`, which takes over the laptop's DNS.
That is an unwanted change to a daily machine that cannot present guests as L2 citizens anyway (wifi does not bridge), so the standing enablement waits for the first wired server host.
The build and bridge-name evaluation were verified by temporarily enabling the Module on `neogaia` (`nix flake check` passed, `nix eval` showed `br-vlan10`/`br-vlan20`), then reverting.
Both stay reproducible from the committed tree by enabling the Module ad hoc through `nixosConfigurations.neogaia.extendModules`, leaving the host file untouched.

No Guest is wired to a bridge — that is the guest networking placement slice.
