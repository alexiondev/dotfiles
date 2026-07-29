---
status: superseded by ADR-0002
---

# Use sops-nix for secrets

The repo is public, so no secret — including password hashes and the WireGuard/ProtonVPN key — may be committed in plaintext. We manage all secrets with **sops-nix**: encrypted into the repo and decrypted per-host at activation via an age key derived from each machine's SSH host key.

We chose sops-nix over agenix for its multi-recipient encryption (one secret readable by both a host and the admin laptop) and its grouped-file editing workflow, which scale better across the planned five hosts with a mix of shared and per-host secrets. The cost is slightly more upfront machinery than agenix's one-file-per-secret model.

## Consequences

- User/root passwords use `hashedPasswordFile` backed by a sops secret, never a committed hash.
- Each new host must have its SSH host public key registered as a recipient before it can decrypt its secrets.
