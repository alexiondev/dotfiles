## Problem Statement

`neogaia` is up and running the NixOS it builds, but its login password was set by hand through `nixos-enter` during the install and lives only on that laptop's disk.
It is the one piece of the machine that is not declared, not reproducible, and not recoverable — a reimage loses it, and no other `Host` can inherit it.

The same gap blocks everything queued behind it.
An Anthropic API key cannot be provisioned declaratively, a WireGuard key cannot be committed, and the three planned servers cannot carry service credentials.
The repo is public and mirrored to GitHub, so none of that material can be committed in plaintext.

There is a second, subtler cost.
SSH host keys are currently generated fresh by `sshd` on each install, so reimaging any machine invalidates its host identity and breaks `known_hosts` for every client that ever connected to it.

`ADR 0001` chose `sops-nix` for this, but its stated mechanism — age keys derived from each `Host`'s SSH host key — turns out to be the wrong topology, and its consequences no longer describe what should be built.

## Solution

Wire `sops-nix` into the `Skeleton` as unconditional plumbing, with a two-tier age identity model.

An **admin identity** stored outside the repo entirely, in Proton Pass, is a recipient of every secrets file.
It is the durable recovery path: it outlives every machine, is reachable from any device including a live ISO, and is the credential that authorizes adding a new `Host` as a recipient.

A **host identity** — a dedicated age key on each machine's encrypted root — is a recipient of only that machine's own secrets plus the shared file.
It is generated on the machine, never leaves it, and is deliberately not derived from the SSH host key, which is what frees the SSH host keys to become secrets in their own right.

Secrets are `sops`-encrypted into this same public repo.
The ciphertext is safe to publish, and the only artifact that would not be — the admin private identity — is never committed at all.
No second repository is introduced.

The first pass moves the login password off its hand-set value and makes `neogaia`'s SSH host keys stable across reimages.
That exercises both decryption paths — the early one that runs before user creation, and the ordinary activation one — proving the machinery end to end on the two secrets that are actually needed today.

## User Stories

1. As the operator, I want my login password declared as an encrypted secret rather than typed into a running machine, so that it is reproducible and survives a reimage like everything else in the flake.
2. As the operator, I want secrets encrypted into the existing public repo rather than a separate private one, so that there is one repository to clone and no bootstrap credential is needed to reach my own configuration during an install.
3. As the operator, I want an admin identity held in my password manager and never committed, so that nothing brute-forceable is published and I can recover every machine from a device I have never used before.
4. As the operator, I want each `Host` to hold its own age identity, so that a compromised server cannot decrypt my laptop's secrets.
5. As the operator, I want a shared secrets file alongside per-`Host` ones, so that material common to every machine is stored once rather than duplicated five times.
6. As the operator, I want my workstation to be a recipient of only its own secrets, so that the admin identity stays a break-glass credential rather than something sitting unlocked on a laptop.
7. As the operator, I want `neogaia`'s SSH host keys stored as secrets and restored at activation, so that reimaging the laptop does not invalidate its host identity or break `known_hosts` for clients.
8. As the operator, I want the secrets machinery to live in the `Skeleton` rather than behind an `enable` flag, so that it reads as plumbing every `Host` depends on rather than an optional feature.
9. As the operator, I want individual secrets declared next to the configuration that consumes them, so that a reader finds the secret where they find its use.
10. As the operator, I want a mistyped secret name or a missing secrets file to fail the build, so that errors surface at `nix flake check` rather than at boot.
11. As the operator, I want the procedure for provisioning a new `Host`'s identity written down, so that installing the desktop and the servers does not require rederiving the key ceremony under pressure.
12. As the operator, I want the recovery path documented for a machine whose identity was provisioned wrongly, so that a failed first boot is a known procedure rather than an improvised one.
13. As the operator, I want the editing workflow documented, so that I know which secrets I can change from my laptop and which require unlocking the admin identity.

## Implementation Decisions

**Identity topology**

- Two tiers of recipient: one admin identity, plus one identity per `Host`.
  Every secrets file is encrypted to admin and to whichever `Host`s legitimately read it.
- The admin identity is stored as a secure note in Proton Pass and is never committed in any form.
  Only its public recipient appears in the repo.
  No passphrase-encrypted copy is committed: the vault already provides passphrase protection with rate limiting, whereas a committed copy would be offline-brute-forceable by anyone who clones the repo, indefinitely.
- Each `Host` identity is a dedicated age key on the LUKS-encrypted root, generated on that machine and never transmitted.
  It is *not* derived from the SSH host key.
  Decoupling them is what allows the SSH host keys to be secrets themselves; deriving one from the other would be circular.
- An admin recipient on every file is structurally required, not a convenience.
  A file readable only by its own `Host` becomes permanently unrecoverable the moment that machine is wiped, and adding any new recipient must be done by someone who can already decrypt.

**Repository layout**

- One repository, public, unchanged.
  A private repository was considered and rejected: cloning it requires credentials that would themselves become bootstrap material at install time, reintroducing the hand-carried secret the design otherwise eliminates, in exchange for protecting content that is already safe to publish.
- A `sops` configuration file and a secrets directory at the repo root.
- One secrets file per `Host`, encrypted to admin plus that `Host`.
- One shared secrets file encrypted to admin plus every `Host`.
- `neogaia` is a recipient of its own file and the shared file only.
  Editing another machine's secrets requires unlocking the admin identity for that session, which is the intended friction.

**Secrets in this pass**

- The primary user's password hash lives in the shared file, consumed through `hashedPasswordFile`.
  It is marked as needed for users, which makes `sops-nix` decrypt it in an earlier activation stage than ordinary secrets, before accounts are created.
  This is the one ordering subtlety in the design and is the reason the `Host` identity must sit on the root filesystem rather than anywhere later-mounted.
- Storing the password hash in the shared file rather than per-`Host` is deliberate.
  The same password will be used on every machine, so duplicating the identical hash across per-`Host` files would not reduce what an attacker learns — it would only make rotation a five-file edit.
- `neogaia`'s SSH host **private** keys live in its own `Host` file, with `sshd`'s generated host keys disabled and pointed at the decrypted paths instead.
- SSH host **public** keys are committed in plaintext.
  They are not secret — publishing them is their function — and encrypting them would impose a re-key cycle every time one changes.

**Placement in the flake**

- The machinery goes in the `Skeleton` as unconditional configuration, not behind an `enable` flag.
  This is a deliberate departure from the `Enable convention`, on the same grounds as the overlays and the flakes settings: every `Host` will carry secrets, so the flag would be permanently `true`, and the plumbing is not a feature a `Host` chooses.
- The `Skeleton` carries only the machinery — the flake input, the identity file location, and the default secrets file.
  Individual secrets are declared wherever they are consumed, so the password secret sits beside the user declaration it feeds and the SSH host keys beside the `sshd` configuration.
- `sops-nix` is added as a flake input following the base `nixpkgs`.

**Operational procedures**

- For `neogaia`, which is already installed and running, provisioning happens live: generate the identity on the machine, add its recipient, re-key the affected files with the admin identity, rebuild.
  No reimage and no live ISO are involved.
- For a `Host` that does not yet exist, provisioning happens on the live ISO *before* the install: generate the identity, add its recipient, re-key, write the identity onto the target root, then install.
  The first boot then has everything it needs and cannot fail for want of a key.
  The install already builds from a local clone, so no push is required mid-procedure; the recipient change is committed afterward.
- Both procedures, the editing workflow, and the live-ISO recovery path are documented in the existing install document rather than a new one.

**Decision record**

- A new ADR supersedes `ADR 0001`, which is marked superseded.
  `ADR 0001`'s choice of `sops-nix` over `agenix` still holds and carries forward in a sentence, but its key-derivation mechanism is replaced and its stated consequence — that each new `Host` registers its SSH host public key as a recipient — is inverted, since SSH host keys are now secrets rather than the root of trust.

## Testing Decisions

- A good test here asserts externally-observable build and activation behaviour, not the internals of `sops-nix`.
  Nothing in this feature is our own logic to unit-test; it is configuration wiring, and the meaningful assertions are that the whole `Host` still evaluates and that the secrets actually materialize on a real machine.
- **Primary seam (required):** `nix flake check` building the `neogaia` system toplevel, the same seam the laptop MVI established.
  It carries real weight for this feature rather than merely compiling: `sops-nix` validates secrets files at evaluation time by default, so a missing file, a file that is not valid `sops` output, or a declared secret whose key is absent from it all fail the build.
  Mistyped secret names surface here rather than at boot.
- **Confirmation (manual):** a real activation on `neogaia`.
  This is what proves decryption itself — that the `Host` identity is readable at the right stage, that secrets appear with the declared ownership and mode, that `sshd` adopts the restored host keys, and that login works against `hashedPasswordFile`.
  It cannot be automated without a machine that holds a real identity, and is treated like the reimage in the laptop MVI: manual by nature.
- No new seams are introduced.
  The existing whole-`Host` build remains the highest available point, and the config-merge model makes it the meaningful unit.
- Prior art: the toplevel-build check established by the laptop MVI, already wired as the flake's `checks` output.

## Out of Scope

- The Anthropic API key.
  It is the natural next secret, but it is consumed as an environment variable rather than a file path, and conflating that shape with the bootstrap work would obscure both.
- The WireGuard/ProtonVPN key, which has no `Module` to consume it yet.
- Declarative wifi credentials.
  NetworkManager profile secrets are fiddly and joining from the console currently works.
- Fleet-wide SSH host verification.
  With one `Host` there is nothing to verify against, and the choice of whether to identify machines by name or address should be made when a second machine exists and the answer is known rather than guessed.
- Provisioning any identity for a `Host` that does not exist yet.
  The procedure is documented; no key is generated for `zeus` or the servers.
- Rotating the LUKS passphrase or coupling it to secret decryption.
- Hardware-token identities.
  A YubiKey can be added later as an additional admin recipient without changing any decision here.
- Any change to how the flake is fetched during an install.

## Further Notes

- **The lockout risk is confined to fresh installs.**
  On `neogaia` the transition is safe: if activation fails, the rebuild fails and the running generation persists with the existing hand-set password intact.
  A machine being installed for the first time has no such fallback, because the password now arrives only from a decrypted secret — which is exactly why its identity is provisioned before the first boot rather than after it.
- **The admin identity is the single point of recovery**, and its durability is now a property of Proton Pass rather than of any machine or repository.
  Losing the vault without a backup means losing the ability to add recipients or recover a wiped `Host`, even though every currently-running machine keeps working from its own identity.
- **Stable SSH host keys were nearly given up** in favour of deriving identities from them, and were recovered by inverting the dependency.
  The rule that made it work generalizes: exactly one secret per machine must arrive out of band, and making that one thing a purpose-built key rather than a repurposed one keeps everything else declarable.
- **Adding a `Host` is a re-key, not a re-encrypt.**
  A `sops` file holds a single data key encrypted once per recipient, so registering a new machine rewrites only that metadata, and the cost stays constant as the fleet grows to five.
- **This is what `ADR 0001` chose `sops-nix` for.**
  The shared-plus-per-`Host` file split with overlapping recipients is precisely the multi-recipient, grouped-file model that decided against `agenix`; the topology change replaces how identities are obtained, not why the tool was picked.
