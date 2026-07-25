---
spec: guests
blocked-by: 0001-toolkit-bundle
---

## What to build

The tracer bullet for the Guest concept: the thinnest complete path from discovery to a running nested container.
The Auto-loader gains a third kind, discovering every Guest under `guests/` the way it already discovers Modules and Hosts.
The shared base config splits into a host base (`system.nix`, carrying host-only machinery — bootloader, hardware profile, host identity, boot and garbage-collection timers) and a slim guest-base that every nested Guest stands on.
Both keep the primary user, home-manager, and the shared overlays; the guest-base additionally auto-enables the `toolkit` bundle and `modules.ssh`, and imports the full `modules/` tree so any Module is available inside a Guest.
A minimal sample Guest is Module-shaped: it declares its own `guests.<path>` namespace with an `enable` and a `backend` field (default `container`, `microvm` reserved but not built), and guards its body per the Enable convention.
Its body's payload — the one difference from a Module — realizes a nested container running the Guest's interior on the guest-base.
A Host enables the sample Guest exactly as it enables a Module, and the whole thing builds through the existing `nix flake check` seam.

## Acceptance criteria

- [x] The Auto-loader discovers and wires every Guest under `guests/` as a third kind, with no manual `imports` edits, and a Guest's option path mirrors its `guests/` location per the Namespace convention (including the index-node and file-or-folder rules).
- [x] The shared base config is split into a host base and a slim guest-base; the existing Host still builds via `nix flake check` with its host-only machinery intact.
- [x] The guest-base includes the primary user, home-manager, and the shared overlays, auto-enables `toolkit` and `modules.ssh`, and imports the full `modules/` tree.
- [x] A sample Guest declares `guests.<path>.enable` plus a `backend` field defaulting to `container`, guards its body on `enable`, and realizes a nested container running its interior when a Host enables it.
- [x] The `microvm` backend value is accepted as reserved but unimplemented, failing clearly rather than silently building nothing.
- [x] A Host enabling the sample Guest builds via `nix flake check`, the guest is reachable from its Host by `machinectl` with no per-Guest configuration, and the baseline toolset and SSH access are present inside it.

## Implementation Notes

- The base split is realized as three files, not two.
`base.nix` is the shared substrate both bases build on — the primary user, home-manager, the `unstable`/`stable` overlays, and flakes.
`system.nix` (the host base) imports it and adds the host-only machinery (bootloader limit, sops decryption and the password, the maintenance timers, the chaotic cache, console keymap).
`guest.nix` (the guest-base) imports it and adds the slim guest layer.
Factoring the common substrate out keeps "both include the primary user, home-manager, and the shared overlays" a single fact rather than a duplicated one.

- The guest-base imports `sops-nix` and `stylix` alongside the full `modules/` tree.
This is load-bearing, not incidental: the module system pushes an `mkIf` down to the leaves it guards, so an option path a module names must be *declared* even where its `enable` is off.
`modules/ssh.nix` names `sops.*` and the desktop modules name `stylix.*`, so those option namespaces have to exist for the tree to evaluate inside a guest that leaves them disabled.

- `modules/ssh.nix` gained a guest flavor.
`hostKeys.restore` (default on) gates restoring host keys from secrets, and both `hostKeys.sopsFile` and `userKey.sopsFile` are now nullable.
A guest sets `restore = false` and names no sops files, so its daemon self-generates a host key and it carries no age key — verified: the interior's `sops.secrets` is empty and `services.openssh.hostKeys` falls back to the generated defaults, while `neogaia` still restores its committed host keys with `openssh.hostKeys = [ ]`.

- The namespace mirroring is honored by author discipline, exactly as a Module's is: `my.guest { name = "sample"; }` names the option path, and `guests/sample.nix` places it.
The Auto-loader change is the same recursive `collectNixFiles`, so the index-node and file-or-folder rules a folder-shaped guest would use come for free from the loader that already serves Modules — no folder-shaped guest exists yet to exercise them.

- The guest gets `privateNetwork = true` by default, so its interior sshd never contends with the host's on the shared namespace.
It is `mkDefault`, so the networking foundation can later attach the guest to a VLAN bridge.

- `backend` is an `enum [ "container" "microvm" ]` defaulting to `container`.
`microvm` is built by nothing; choosing it trips a build-time assertion with a clear message rather than silently producing no container, per the acceptance criterion and ADR 0006's reserved-value decision.

- `neogaia` enables `guests.sample` to demonstrate the path end to end, the way it demonstrated `modules.toolkit`.
This means a rebuild starts a live nspawn container on the laptop; it is a minimal smoke test and can be turned off with one line.

- `nix flake check` passes and builds the nested `nixos-system-sample` interior in full.
A pre-existing nixvim warning about its own `nixpkgs.follows` now also prints for the guest's reused Neovim config; it is upstream noise, not a defect in this change.
