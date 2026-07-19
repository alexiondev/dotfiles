---
spec: sops-secrets
blocked-by: 0010-sops-skeleton-and-password
---

## What to build

`neogaia`'s SSH host keys become secrets, so reimaging the laptop no longer invalidates its host identity or breaks `known_hosts` for every client that has ever connected to it.

Introduce a per-host secrets file for `neogaia`, encrypted to the admin identity plus `neogaia` alone — the first file in the repo that is not readable by the whole fleet, and the thing that keeps a compromised machine from decrypting another's material.
The host's SSH **private** keys go in it.

The host **public** keys are committed in plaintext.
Publishing them is their function, and encrypting them would impose a re-key cycle every time one changes.

Stop the SSH daemon generating its own host keys and point it at the decrypted paths instead.
These secrets decrypt in the ordinary activation stage rather than the early pre-user one, so this slice exercises the second of the two decryption paths.

## Acceptance criteria

- [ ] A secrets file for `neogaia` exists, encrypted to the admin identity and `neogaia` only — not to any other recipient
- [ ] `neogaia`'s SSH host private keys are stored in it
- [ ] The corresponding host public keys are committed in plaintext
- [ ] The SSH daemon no longer generates its own host keys and reads the decrypted paths
- [ ] The host key secrets are declared beside the SSH daemon configuration that consumes them
- [ ] `nix flake check` builds the `neogaia` toplevel
- [ ] Manual confirmation: after activation the secrets materialize with the declared ownership and mode, the daemon adopts the restored keys, and the host fingerprint presented to a client is unchanged
