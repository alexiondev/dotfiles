# Guests

## Problem Statement

The user runs a homelab on Proxmox with LXC system containers and Podman, replacing it with a fully declarative NixOS configuration where both the machines and the services they host are NixOS, built from this one flake.
Each service today is an isolated guest that is a first-class citizen on a VLAN-tagged LAN: it has its own MAC address and its own IP on a specific tagged VLAN, and it writes to shared ZFS pools without permission errors.
The flake currently has only two concepts, the Host and the Module, and a Module can only be turned on at host level.
There is no way to express "run this service isolated in its own guest, on this VLAN, with these pool mounts" declaratively, and no way to reuse such a definition across machines.
The Proxmox setup the user is leaving also imposes an imperative container lifecycle and mutable state that drifts outside version control, which is the thing the migration exists to eliminate.

## Solution

Introduce a third concept alongside Host and Module: the Guest.
A Guest is a reusable, machine-independent definition that bundles the Modules it runs inside an isolated NixOS instance, realized on a Host as a nested container.
A Host composes both Modules and Guests and reads as one flat checklist, where a Module turned on directly is a host-level install and a Guest is a service running in its own isolated instance.
Each Guest becomes a first-class L2 citizen on a chosen tagged VLAN with its own MAC and its own IP, writes to shared pools through a common storage group with no permission juggling, and carries its own resource caps and secrets.
Every Guest ships with the user's baseline interactive toolset and SSH access, so any guest the user shells into is immediately a workable environment.
A Guest can also run Podman or other OCI containers in its interior, which is the declarative home for image-only software that is not worth reimplementing in Nix.
The foundations a Guest stands on — declarative VLAN and bridge networking, ZFS pool import, and a shared write convention — are themselves host-level Modules, so a Host declares its trunk, its VLANs, and its pools once and every Guest attaches to them.

## User Stories

1. As the operator, I want to define a service as a Guest in its own file, so that the service and everything it runs are one reusable, version-controlled fact.
2. As the operator, I want a Guest to follow the same file, folder, and namespace conventions as a Module, so that I never learn a second layout and a Guest's location is its namespace.
3. As the operator, I want a Host to turn a Guest on with `enable` exactly as it turns a Module on, so that a Host stays a single flat checklist of everything it carries.
4. As the operator, I want a Module placed directly on a Host to mean a host-level install and a Guest to mean an isolated instance, so that the same checklist expresses both placements without ambiguity.
5. As the operator, I want a Guest to give its service its own MAC and its own IP on a specific tagged VLAN, so that my VLAN-segmented network treats each service as a distinct L2 citizen, exactly as Proxmox did.
6. As the operator, I want to reuse the MAC addresses my existing containers already use, so that my router's DHCP reservations keep working and the migration needs no network reconfiguration.
7. As the operator, I want a Guest whose MAC I did not set to still get a stable, readable MAC, so that I can add a reservation for a new guest without hand-assigning addresses.
8. As the operator, I want a Guest to take its address by DHCP by default and optionally a static address, so that IP management stays centralized at my router where it already lives.
9. As the operator, I want a build-time error when a Guest names a VLAN its Host has not declared, so that a misplacement fails at evaluation rather than as a broken bridge at runtime.
10. As the operator, I want a Guest to mount shared pool paths at any granularity, a single folder or a whole pool, read-only or read-write, so that each service sees exactly the data it should.
11. As the operator, I want every Guest's service to write to shared pools without permission errors, so that I never repeat the Proxmox idmap dance.
12. As the operator, I want a Guest to receive only the decrypted secrets it names, so that services get their credentials while no guest ever holds a decryption key.
13. As the operator, I want to cap a Guest's memory, CPU, and process count, so that one misbehaving service cannot starve its Host.
14. As the operator, I want every Guest to come with fish, tmux, nvim, git, and direnv, so that any guest I shell into feels like my own machine.
15. As the operator, I want to reach a Guest both directly over SSH with my keys and from its Host with `machinectl`, so that I always have a way in whether or not the network path is open.
16. As the operator, I want a Guest to run Podman and OCI containers in its interior by turning on a nesting capability, so that image-only software has a declarative home without a separate mechanism.
17. As the operator, I want the same Guest definition to be deployable on more than one Host by declaring it there with that Host's placement, so that an appliance is portable between machines.
18. As the operator, I want the networking, storage, and write conventions to be host-level Modules I declare once per Host, so that Guests attach to shared foundations instead of each re-specifying the machine.
19. As the operator, I want a Guest's innards fixed in the Guest file and only its placement supplied by the Host, so that a Guest behaves identically wherever it runs and reads honestly in isolation.
20. As the operator, I want to build a Host and know its Guests evaluate and its placements are consistent before I deploy, so that a rebuild is trustworthy.

## Implementation Decisions

### The Guest concept

- A **Guest** is a new, auto-loaded kind of definition, resolved in `CONTEXT.md` and formalized in ADR 0006.
The Auto-loader discovers every Guest under `guests/` as a third kind alongside Modules and Hosts.
- A Guest follows the **Namespace convention** and the file-or-folder rule of a Module verbatim: a plain Guest is one file whose location is its namespace, and a Guest that needs auxiliary files becomes a folder, with subfolders as namespace segments and the same index-node rule (per ADR 0004).
- A Guest is **Module-shaped**: it declares its own `guests.<path>` option namespace carrying an `enable` plus its placement fields, and guards its body on that `enable` following the **Enable convention**.
The one difference from a Module is the payload: a Module's body merges settings into the Host, whereas a Guest's body **realizes a nested container** running the Guest's interior.
- A Guest is **backend-agnostic** through a `backend` field, but only the `container` backend (systemd-nspawn, via the platform's native nested-container mechanism) is built.
`microvm` is a reserved backend value that is not implemented in this work.
- A Guest is **sealed and singleton**: the Modules a Guest runs are fixed in the Guest file and are not overridable by a Host, and a Guest is instantiated at most once per Host, keyed by its namespace path.
Running more than one instance of a service on a Host is out of scope for this work.

### Placement interface (Host-side)

A Host instantiates a Guest by setting fields under `guests.<path>`.
The Guest owns its interior Modules; the Host owns only this placement.

| Field | Meaning | Default |
| --- | --- | --- |
| `enable` | Turn the Guest on for this Host | off |
| `backend` | Realization backend | `container` |
| `vlan` | Tagged VLAN the Guest lives on; maps to the Host's `br-vlan<id>` bridge by convention | required when networked |
| `mac` | The Guest's MAC address; set it to reuse an existing address | derived deterministically and surfaced when unset |
| `address` | Static address on the VLAN | unset, meaning DHCP |
| `mounts` | Map of guest path to host path, each with a per-mount `readOnly` | read-write per mount |
| `secrets` | Names of secrets the Guest needs | none |
| `limits` | `memory`, `cpu`, `tasksMax` caps applied to the guest's unit | uncapped |
| `nesting` | Grant the nested-container prerequisites so the interior can run Podman/OCI | off |
| `autoStart` | Start the Guest at boot | on |

- The `vlan` field maps to a bridge by the `br-vlan<id>` **naming convention**, so a Guest states only which VLAN it lives on.
- A **build-time assertion** ties a Guest's `vlan` to the set of VLANs its Host's network foundation declares, so a Guest on an undeclared VLAN fails the Host build with a clear message.
- The `mac` field is pinned inside the guest through the guest's own systemd-networkd, which is the only way a nested-container MAC is stable; an unset `mac` derives a stable address from the Guest's namespace path in a locally-administered range, readable via evaluation so the operator can add a reservation.
- The `mounts` field is realized as the nested container's bind mounts and defaults to read-write, matching the migration reality that services must write to pools.
- The `nesting` field is what makes the OCI fallback a plain Guest: the Skeleton emits the nested-container cgroup-delegation and capability prerequisites once, so the operator flips one boolean and the interior's `oci-containers` runtime works, with Podman as the default runtime.

### Bases and the shared environment

- The shared base config **splits in two** (recorded under the Skeleton term): a **host base** that carries host-only machinery (bootloader, hardware profile, host identity, boot and garbage-collection timers), and a slim **guest-base** that every nested Guest stands on.
- Every Guest **imports the full `modules/` tree**, so any Module is available to enable inside a Guest; only Modules whose needs the base meets are enabled in practice.
- A Guest gets **home-manager and the same primary user** as a Host, which makes every Module placement-agnostic and removes any need for a host-versus-guest Module taxonomy.
- The **guest-base auto-enables** the `toolkit` bundle and `modules.ssh`, so every Guest has the baseline toolset and SSH access without per-Guest wiring.
Reaching a Guest by `machinectl` from its Host needs no Guest configuration and is the always-available fallback.

### New and modified Modules

- **`modules.toolkit`** (new): a deliberate bundle Module turning on fish, tmux, nvim, git, and direnv as one unit.
The guest-base auto-enables it; a Host enables it explicitly, keeping the Host a full checklist.
This is a bundle wanted as a unit, distinct from the grouping-directory enables ADR 0004 rejected.
- **`modules.network`** (new): the host-level networking foundation.
A Host declares its trunk interface and the set of VLANs to materialize, and the Module emits one bridge per tagged VLAN with systemd-networkd and manages the Host's own management address.
- **`modules.zfs`** (new): the host-level pool import.
A Host declares its host id, the pools to import, and their dataset mountpoints; the pools are durable state that is imported, never rebuilt.
- **A shared `storage` group** with a fixed gid in the shared base gives 1:1 ownership between Host and Guest.
Because the container backend uses identity mapping, a guest service that writes as the `storage` group lands on the pool as that same group, which is the entire "no permission errors" mechanism.
- **`modules.ssh`** (reused): the guest-base enables it in a guest flavor, with the operator's authorized keys and a self-generated host key, since a Guest does not carry a per-Guest host identity the way a Host does.
- **The Skeleton** grows the Guest realization: the Auto-loader's discovery of `guests/`, the compilation of a Guest's interior into a nested container, and the wiring of placement fields (VLAN attachment, MAC pinning, bind mounts, secret mounts, unit caps, nesting prerequisites).

### Secrets

- The **Host is the sole decryptor**, consistent with the host identity of ADR 0002 and the existing sops-nix setup.
The Host decrypts, and a Guest receives only the specific secret files it names, read-only bind-mounted in, with ownership aligned by the identity mapping.
A Guest holds no age key.

## Testing Decisions

A good test here exercises **external, observable behavior of a Guest and its foundations**, not the internal shape of the generated nested-container config.
The load-bearing behaviors are: a Guest presents its own MAC and its own IP on the correct tagged VLAN, a guest service writes to a shared-group mount without permission error, the baseline toolset and SSH access are present, and a misplaced Guest fails the build.

Two seams, the fewest that cover the work:

1. **The Host toplevel build via `nix flake check`** — the existing, primary seam every Host already has.
This is where a Guest's evaluation, its placement fields, the base split, the Auto-loader wiring, and the `vlan`-against-declared-VLANs assertion are all verified.
Cheap targeted evaluations of derived values (a Guest's resolved bridge attachment, its derived MAC, the shared `storage` gid) ride on this same seam.
2. **One NixOS VM integration test**, added to the flake's `checks` so `nix flake check` runs it — a new seam, and the highest behavioral one available.
A single harness boots the `modules.network` foundation and one sample Guest and asserts the three hard requirements together: the guest has its own MAC, gets its own IP on a tagged VLAN across a virtual L2 segment, and can write to a bind-mounted directory owned by the shared `storage` group.

Prior art: the flake's `checks.<host>` toplevel builds are the established evaluation seam; the upstream NixOS test suite exercises nested-container networking, including macvlan and extra-veth cases, and is the model for the VM integration test.
The two behaviors a VM cannot honestly reproduce — real 802.1Q against the physical switch and real ZFS identity-mapped writes on the pool — are verified manually on the target Host rather than in the test.

## Out of Scope

- The `microvm` backend and any hard-isolation guest; the concept reserves the backend value but this work does not build it.
- Running more than one instance of a service on a Host; the Guest stays singleton and the operator will address multiplicity separately.
- Exotic OCI images that need their own nested init or unusual storage drivers, which are the future reason to reach for the microvm backend.
- The concrete homelab Host itself and its real values — its trunk interface name, VLAN ids, pool names, and per-Guest MAC and mount assignments — which are host-specific data supplied when a Host is added.
- Migrating specific services (the *arr stack, download clients, media servers) into Guests; this work delivers the concept and its foundations, not the service catalogue.
- Real-switch VLAN behavior and real ZFS identity-mapped writes, which are verified manually on the target Host.

## Further Notes

- The decision to introduce Guest as a third concept, backend-agnostic but container-only for now, sealed and singleton, is recorded in ADR 0006.
- The "no permission errors" result rests on the container backend's identity mapping being the privileged-container equivalent the operator already trusts from Proxmox; it is deliberately not the unprivileged idmap model, which is what made pool writes painful before.
- Pools are durable state imported by the Host, never recreated by a rebuild, so a service's data survives any rebuild or reimage.
- Podman is the default and recommended runtime inside a nesting Guest, matching what the operator already runs; a container-backend Guest is soft-isolated (shared kernel), the same isolation class as the Proxmox LXCs being replaced, so nothing is lost on that axis in the move.
