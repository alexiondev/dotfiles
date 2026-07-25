---
status: accepted
---

# A Guest is a third concept beside Host and Module

The flake gains a third first-class concept, the Guest, beside the Host and the Module.
A Guest is a reusable, machine-independent definition under `guests/` that bundles the Modules it runs inside an isolated NixOS instance, realized on a Host as a nested container.
A Host composes both Modules and Guests: a Module turned on directly is a host-level install, and a Guest is a service running in its own isolated instance, so a Host still reads as one flat checklist of everything it carries.

A Guest follows the Modules convention wholesale.
The Auto-loader discovers `guests/` as a third kind, the Namespace convention and file-or-folder rule apply unchanged (`guests/media/jellyfin.nix` declares `guests.media.jellyfin`), and a Guest is Module-shaped: it declares its own `guests.<path>` option namespace with an `enable` and its placement fields and guards its body on that `enable` per the Enable convention.
The single difference from a Module is the payload — a Module's body merges settings into the Host, while a Guest's body realizes a nested container running the Guest's interior.

A Guest is backend-agnostic through a `backend` field but only the `container` backend (systemd-nspawn) is built now; `microvm` is a reserved value for a future hard-isolation backend.
A Guest is sealed and singleton: its interior Modules are fixed in the Guest file and not overridable by a Host, which supplies only placement, and a Guest is instantiated at most once per Host.
Every Guest stands on a slim guest-base, distinct from the host base carved out of the shared base config, and imports the full `modules/` tree so any Module is available inside it.

We chose this because the homelab this flake is growing to build runs services as isolated guests that are first-class citizens on a VLAN-tagged network, and the two-concept model had no way to say "run this service in its own instance, on this VLAN, with these pool mounts" declaratively or to reuse that definition across machines.
Making the Guest a peer of Host and Module — same Auto-loader, same conventions, same checklist — adds the capability without adding a second mental model, and keeps the imperative container lifecycle and mutable drift of the Proxmox setup it replaces out of the flake.

## Considered Options

- **Inline `containers.<name>` per Host.** The platform's native nested-container option, declared directly inside each Host. Rejected: a guest would be tied to one Host with no reuse, and the machine-independent identity of an appliance would be entangled with one machine's config, the same drift ADR 0004 removed for Modules.
- **Incus or another imperative container stack.** A maintained LXC-style manager on the Host. Rejected: its instance lifecycle is imperative and its state mutable, which is precisely the Proxmox property the migration exists to eliminate; guests would not be declared in the flake.
- **A microvm-first Guest.** Realize every Guest as a hard-isolated micro VM from the start. Deferred, not chosen for now: the operator's guests are the soft-isolation class the Proxmox LXCs already are, and a shared-kernel container backend is the like-for-like replacement; the backend field reserves `microvm` for when a guest genuinely needs a distinct kernel.
- **A Guest as a parameterized template with Host-declared instances.** Let one Guest file be stamped out as many named instances per Host. Rejected: it breaks "follow the Modules convention completely" by making a Guest a non-singleton template with its own instance sublevel, a fourth shape; multiplicity is instead expressed as separate Guests over shared, configurable service Modules.

## Consequences

- The Skeleton grows a Guest realization: the Auto-loader discovers `guests/`, a Guest's interior compiles into a nested container, and placement fields wire VLAN attachment, MAC pinning, bind mounts, secret mounts, unit caps, and the nesting prerequisites.
- The shared base config splits into a host base (`system.nix`) and a slim guest-base; both include the primary user, home-manager, and the shared overlays, and the guest-base auto-enables the `toolkit` bundle and `modules.ssh`.
- Guests attach to host-level foundations declared once per Host: `modules.network` for the trunk and per-VLAN bridges, and `modules.storage.zfs` with a shared fixed-gid `storage` group for identity-mapped pool writes.
- OCI software has a declarative home without a new mechanism: a Guest with `nesting` runs Podman in its interior.
- The `microvm` backend, multi-instance Guests, and the concrete homelab Host with its real trunk, VLAN, pool, and MAC values remain future work.
