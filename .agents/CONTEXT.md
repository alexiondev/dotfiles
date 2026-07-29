# NixOS Dotfiles

A single flake that builds every machine the user owns — laptop, desktop, and three servers — from one shared, modular configuration.

## Language

**Host**:
One physical machine the flake builds a NixOS configuration for. Each Host has a directory under `hosts/` holding its machine-specific `hardware-configuration.nix` and its choice of enabled Modules.
_Avoid_: machine, node, system, box

**Module**:
A single `.nix` feature file under `modules/` that declares an `enable` option and the configuration it turns on. Every Module is always imported but stays inert until a Host enables it.
_Avoid_: component, package, plugin

**Guest**:
A reusable, machine-independent definition under `guests/` that bundles the Modules it runs inside an isolated NixOS instance, realized on a Host as a nested container.
Its `backend` defaults to `container` (systemd-nspawn).
`microvm` is a reserved backend value that is not yet built.
A Guest follows the Modules convention wholesale: the file-or-folder layout, the Namespace convention (`guests/media/jellyfin.nix` declares `guests.media.jellyfin`), and the Enable convention (imported always, inert until a Host sets its `enable`).
The Guest owns only its interior Modules.
The Host that enables it supplies the machine-specific placement, such as its VLAN, pool mounts, and resource caps.
_Avoid_: container, VM, instance, LXC, appliance

**Skeleton**:
The flake's plumbing — the Auto-loader, the helper lib, the flake inputs/overlays, and the shared base config — as distinct from the Modules that sit on top of it.
The shared base config splits in two: a host base (`system.nix`) and a slim guest-base that every nested Guest stands on.
The host base carries host-only machinery, such as the bootloader, hardware profile, host identity, and the boot and garbage-collection timers.
The guest-base carries only what a nested service needs and auto-enables the `toolkit` bundle and `modules.ssh`.
Both include the primary user, home-manager, and the shared overlays.
_Avoid_: framework, core, base, scaffolding

**toolkit**:
A deliberate bundle Module (`modules.toolkit`) that turns on the baseline interactive environment — fish, tmux, nvim, git, direnv — as one unit, so any Host or Guest shell feels identical.
The guest-base auto-enables it; a Host enables it explicitly like any other Module, keeping the Host a full checklist.
Distinct from the grouping-directory enables ADR 0004 rejected, since this is a bundle wanted as a unit.
_Avoid_: base, workstation, essentials

**Auto-loader**:
The lib code that recursively discovers and imports every Module under `modules/`, every Host under `hosts/`, and every Guest under `guests/`, so new files wire themselves in without manual `imports` edits.
_Avoid_: loader, importer, scanner

**Enable convention**:
The rule that every Module is imported unconditionally and guards its own body with `mkIf config.modules.<path>.enable`, so a Host reads as a checklist of `enable = true` flags.
_Avoid_: feature flag, toggle, opt-in

**Namespace convention**:
The rule that a Module's option path mirrors its directory path under `modules/`, so a file's location is its namespace.
A file whose name matches its enclosing directory is that directory's index node, declaring the directory's own segment rather than a doubled one.
A directory with no such file is a pure namespace prefix that carries no aggregate enable.
_Avoid_: option tree, module path, config key

**admin identity**:
The age identity held only in the operator's password manager, never committed, that is a recipient of every secrets file.
It is the recovery path for any wiped machine and the credential that authorizes registering a new host.
_Avoid_: master key, admin key, root key

**host identity**:
The dedicated age key on one machine's encrypted root, generated there and never transmitted, that decrypts that machine's own secrets and the shared file.
Deliberately distinct from the machine's SSH host key.
_Avoid_: machine key, node key, host key

**secrets file**:
One sops-encrypted file in the repo, encrypted to the admin identity plus whichever hosts may read it. Either shared across every host or specific to one.
_Avoid_: vault, secret store, keyring

**unstable overlay**:
The overlay exposing `nixpkgs-unstable` packages as `unstable.<name>`, used to pull an individual package fresher than the `nixos-unstable` base.
_Avoid_: bleeding-edge, latest

**stable overlay**:
The overlay exposing the latest stable release (`nixos-26.05`) as `stable.<name>`, used to pin an individual package to the rock-solid release from the `nixos-unstable` base.
_Avoid_: LTS, release channel
