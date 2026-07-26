---
spec: guests
blocked-by: 0002-guest-walking-skeleton
---

## What to build

The Host-side placement that gives a Guest only the decrypted secrets it names, while no Guest ever holds a decryption key.
A Host sets `secrets`, the names of the secret files the Guest needs.
The Host is the sole decryptor, consistent with the host identity and the existing sops-nix setup: it decrypts, and the Guest receives only the specific named secret files, read-only bind-mounted in, with ownership aligned by the identity mapping.
A Guest holds no age key.

## Acceptance criteria

- [x] A Host setting `guests.<path>.secrets` gives the Guest exactly the named secret files and no others.
- [x] The named secrets are decrypted by the Host and bind-mounted into the Guest read-only, with ownership aligned by the identity mapping.
- [x] The Guest holds no age key and performs no decryption of its own.
- [x] A Host with a Guest that names secrets builds via `nix flake check`, and the resolved secret mounts are verifiable by `nix eval`.

## Implementation Notes

`secrets` is a placement option on the `guest` builder: a list of secret names.
For each name the builder declares `sops.secrets.<name>` on the host, so the host is the sole decryptor from the sops files it already holds, and bind-mounts the decrypted file read-only into the guest at the same `/run/secrets/<name>` path it occupies on the host.
A service inside the guest therefore reads its credentials at the location it would on a host, keeping a module placement-agnostic.

The guest holds no age key and declares no secrets of its own.
This is inherited, not added: `guest.nix` stands on `base.nix`, not on the host base `system.nix` that sets `sops.age.keyFile`.
Verified through `nixosConfigurations.neogaia.extendModules`: with `guests.sample.secrets = [ "alexion-password" ]`, the interior's `sops.age.keyFile` is null and its `sops.secrets` is empty, while the host declares the secret and the container's `bindMounts` carries exactly the one entry, read-only, keyed and sourced at the secret's path.

Ownership alignment needs no new code.
The container already runs with `privateUsers = "no"` (task 0006), so the host and guest share one uid and gid space, and the decrypted file's host owner is its owner inside the guest.
A secret defaults to `root:root` mode `0400`, so a guest service running as a non-root user needs the operator to set `sops.secrets.<name>.owner` on the host, which merges cleanly with the builder's stub declaration.
The `secrets` field stays a list of names per the spec, which treats the owner as host-set data.

A build-time assertion rejects an in-guest path claimed by both a `mounts` entry and a secret, since the two attribute sets merge and the collision would otherwise resolve silently in the secret's favour.

No host commits a `secrets` placement, mirroring the mounts, networking, and storage foundations (tasks 0003–0006): the only host, `neogaia`, is a laptop carrying no service that names one.
`nix flake check` passes on the committed tree, where the sample guest declares no secrets.
The full host toplevel was built with the sample guest naming `alexion-password` (a real key in `secrets/shared.yaml`); sops-nix validates at build time that each named key exists in the host's sops files, so a build with a name absent from those files fails clearly rather than at activation.
Real identity-mapped reads on the target host are verified manually, per the spec's testing decisions.
