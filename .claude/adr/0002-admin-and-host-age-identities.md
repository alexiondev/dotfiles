---
status: accepted
---

# Two-tier age identities, secrets in the public repo

Secrets are encrypted with sops-nix into this public repo and decrypted by a two-tier set of age identities: one **admin identity**, stored only in Proton Pass and never committed, which is a recipient of every secrets file; and one **host identity** per machine, a dedicated age key generated on that machine's encrypted root, which reads only its own secrets plus the shared file.
The admin identity makes secrets recoverable after any machine is wiped and is the credential that authorizes registering a new host; the host identities keep a compromised server from decrypting the laptop.
Deliberately, a host identity is *not* derived from its SSH host key — that decoupling is what lets the SSH host keys themselves be secrets, so they survive a reimage instead of being regenerated.

This supersedes ADR 0001, whose choice of sops-nix over agenix still holds — the shared-plus-per-host file split with overlapping recipients is exactly the multi-recipient, grouped-file model that decided against agenix — but whose key-derivation mechanism is replaced.

## Considered Options

- **A separate private repository for secrets.** Rejected: cloning it needs credentials that would themselves be bootstrap material during an install, reintroducing a hand-carried secret to protect ciphertext that is already safe to publish.
- **A passphrase-encrypted admin identity committed to the repo.** Rejected: in a public repo it is offline-brute-forceable indefinitely, whereas a password manager provides the same protection with rate limiting.
- **Deriving host identities from SSH host keys**, as ADR 0001 specified. Rejected: it forces new host keys on every reimage, which means re-keying every secret, and it makes storing the host keys as secrets circular.
- **A single admin identity for all hosts, with no per-host identities.** Rejected: with three servers planned, it gives every machine the ability to decrypt every other machine's secrets.

## Consequences

- Every secrets file must include the admin identity as a recipient. A file readable only by its own host becomes permanently unrecoverable the moment that machine is wiped.
- The admin identity is the single point of recovery, and its durability is now a property of Proton Pass rather than of any machine or repository.
- A host must have its identity provisioned and registered *before* its first boot, because the login password now arrives only from a decrypted secret and there is no fallback credential.
- Registering a new host is a re-key of each file's data key, not a re-encryption of its values, so the cost stays constant as the fleet grows.
