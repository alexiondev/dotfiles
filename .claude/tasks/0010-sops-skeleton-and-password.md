---
spec: sops-secrets
---

## What to build

The tracer bullet for encrypted secrets: a working two-tier age identity model, with the primary user's login password arriving as a decrypted secret rather than a value typed into a running machine.

Establish the two identities the model rests on.
An admin identity is generated and stored as a secure note in the operator's password manager; only its public recipient ever appears in the repo, and no copy of the private half is committed in any form.
A host identity is generated on `neogaia` itself, onto its encrypted root, never transmitted, and deliberately not derived from the machine's SSH host key.

Commit a sops configuration naming both recipients and a shared secrets file encrypted to admin plus `neogaia`, holding the primary user's password hash.
The hash lives in the shared file rather than a per-host one because the same password is used on every machine, so per-host copies would only make rotation a multi-file edit.

Wire the tooling into the flake as unconditional plumbing in the shared base config — not behind an enable flag, on the same grounds as the overlays and the flakes settings.
The base config carries only the machinery: the flake input, the identity file location, and the default secrets file.
The password secret itself is declared beside the user declaration it feeds, so a reader finds the secret where they find its use.

The password secret must be marked as needed for user creation, which decrypts it in an earlier activation stage than ordinary secrets.
That ordering is why the host identity has to sit on the root filesystem rather than anywhere mounted later.

The transition is safe on `neogaia`: if activation fails the rebuild fails and the running generation persists with its existing hand-set password intact.

## Acceptance criteria

- [ ] An admin age identity exists in the operator's password manager; its private half is committed nowhere, in no form
- [ ] A host age identity exists on `neogaia`'s encrypted root and was generated on the machine
- [ ] The sops configuration in the repo names the admin recipient and the `neogaia` recipient
- [ ] A shared secrets file, encrypted to admin plus `neogaia`, holds the primary user's password hash
- [ ] The secrets flake input is added, following the base nixpkgs
- [ ] The shared base config carries the machinery unconditionally — identity file location and default secrets file — with no enable flag
- [ ] The password secret is declared beside the user declaration, consumed through `hashedPasswordFile`, and marked as needed for user creation
- [ ] `nix flake check` builds the `neogaia` toplevel; a mistyped secret name or missing secrets file fails it
- [ ] Manual confirmation: `neogaia` activates, and console login succeeds against the decrypted password hash
