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

- [x] A secrets file for `neogaia` exists, encrypted to the admin identity and `neogaia` only — not to any other recipient
- [x] `neogaia`'s SSH host private keys are stored in it
- [x] The corresponding host public keys are committed in plaintext
- [x] The SSH daemon no longer generates its own host keys and reads the decrypted paths
- [x] The host key secrets are declared beside the SSH daemon configuration that consumes them
- [x] `nix flake check` builds the `neogaia` toplevel
- [x] Manual confirmation: after activation the secrets materialize with the declared ownership and mode, the daemon adopts the restored keys, and the host fingerprint presented to a client is unchanged

## Implementation Notes

**Both key types were preserved, not just ed25519.**
The running daemon served an ed25519 and an RSA host key, and a client that pinned either would break if only one were carried over.
Both private halves are in `secrets/neogaia.yaml`.

**The decrypted keys stay at their default `/run/secrets/` paths.**
The first attempt set each secret's `path` to the conventional `/etc/ssh/ssh_host_*_key`, which has sops plant a symlink inside a directory NixOS otherwise manages through `setup-etc`.
It worked, but it buys nothing: `sshd` reads whatever `HostKey` names, and the extra `/etc` interaction depends on activation ordering that nothing in the config pins.
The `HostKey` lines now interpolate `config.sops.secrets.<name>.path`, so the daemon and the secret cannot disagree about where the key is.
`/etc/ssh` ends up holding no key material at all.

**`restartUnits = [ "sshd.service" ]` is not in the plan and is needed.**
`sshd` reads its host keys once at startup.
Without this, re-keying the host would rewrite the decrypted files while the daemon kept serving the old keys from memory until some unrelated restart — silently, and precisely the identity drift this task exists to prevent.
The plan's manual criterion would not have caught it, since it was verified on a switch where the keys had not changed.

**The committed public keys have no consumer yet.**
An intermediate version deployed them to `/etc/ssh` via `environment.etc`.
That was dropped as scope the task did not ask for: `sshd` derives the public half from the private key at load, so nothing read them.
They are committed, per the criterion, and the task that distributes `known_hosts` to clients is where they acquire a use.

**Verification was stronger than a before/after comparison.**
After activation the leftover `/etc/ssh/ssh_host_*_key` symlinks from the first attempt were removed and `sshd` restarted with no key material anywhere in `/etc/ssh`.
It came back active and presented `SHA256:2ysuBX0+Z6GbdCTujz5JHX6rqnJzIyWhYNrxdhhGwEM` (ed25519) and `SHA256:y6Tl3P/FvfufblfG059BfCsSkMYX8Zk2EpFQvWzCAew` (RSA) — identical to the pre-change fingerprints.
The generated `sshd-keygen.service` has no `ExecStart` at all, which is what confirms generation is off rather than merely idle.
Separately, the encrypted file was decrypted with the host identity and diffed against the live private keys before anything was changed.

**Task 0010's handoff about `authorizedKeys` is deliberately left open.**
That note proposed settling it here, on the grounds that SSH is not a recovery route while no key is authorized.
It is not an acceptance criterion of this task, and choosing which public key to trust is the operator's call rather than one to infer.
It wants its own task, and remains a real gap: a decryption failure that locks the console still has no network fallback.
