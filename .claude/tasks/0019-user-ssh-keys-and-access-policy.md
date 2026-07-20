---
blocked-by: 0011-neogaia-ssh-host-keys
---

## What to build

The operator's SSH client key becomes a secret, and which machines may reach which becomes a declared policy rather than a hand-edited list.

Today the key that authenticates pushes to the remote exists only as a file created by hand on one laptop.
It is in no secrets file and no module, so a reimage destroys it.
That is worse than losing a host key: a lost host key makes clients complain about `known_hosts`, whereas a lost client key locks the operator out of the remote until a new one is generated and registered through the forge's web interface.

Each machine gets its **own** client identity rather than one shared across the fleet.
The private half lives in that machine's own secrets file, so it is readable by that machine and the admin identity alone.
A compromised machine therefore surrenders only its own key, and withdrawing a machine's access means removing one public key rather than re-keying every other machine.
The public halves are committed in plaintext, as the host public keys are, since publishing them is their function.

The private half decrypts at activation and is readable only by the primary user.
Following the host keys, the client is pointed at the decrypted path rather than having a copy written into the user's home, so there is one authoritative location for the key and no copy to drift.

Access is expressed as a policy over machine roles, not as a per-host list of authorized keys.
A **workstation** may reach every machine in the fleet.
A **server** may reach other servers only.
Consequently every machine authorizes the workstation keys, and servers additionally authorize the server keys, while a workstation never authorizes a server's key — so a compromised server cannot reach the operator's own machines.

This wants a single declaration of the fleet, naming each machine's role and its client public key, from which every host derives the set it authorizes.
Registering a new machine is then declaring its role in one place, rather than an edit to every other host's configuration.

Only `neogaia` exists today, so the server half of the policy has nothing to act on and cannot be exercised.
It is built and recorded now so that the desktop and the three planned servers are a role declaration rather than a redesign.

Adopt the key already present on `neogaia` rather than generating a fresh one.
It is already registered with the remote, so adopting it keeps pushes working, whereas replacing it would require registering the new key through the web interface before the old one stops being used — an ordering that locks the operator out if it goes wrong.
Machines that do not exist yet generate their own key during provisioning, alongside the age identity.

This also settles the gap left open by task 0010, where the daemon accepts connections but authorizes no key, so a failed decryption that locks the console has no network fallback.
Note that the fallback only becomes real once a second machine exists to connect from.

## Acceptance criteria

- [x] `neogaia` has its own client SSH identity, distinct from its host keys, adopted from the key already on the machine
- [x] Its private half is stored in `neogaia`'s own secrets file, encrypted to the admin identity and `neogaia` alone
- [x] Its public half is committed in plaintext
- [x] The private half decrypts at activation, readable only by the primary user and not by other accounts
- [x] The SSH client uses the decrypted key with no hand-placed copy in the user's home directory
- [x] Each machine declares a role, and the keys it authorizes follow from that role rather than from a per-host list
- [x] Workstation keys are authorized on every machine
- [x] Server keys are authorized on servers only, and on no workstation
- [x] Registering a new machine is a role declaration in one place, requiring no edit to any other host
- [x] `nix flake check` builds the `neogaia` toplevel
- [x] Manual confirmation: the key materializes with the declared ownership and mode, an authenticated push to the remote still succeeds, and `neogaia` accepts an SSH connection offering the adopted key

## Implementation Notes

The fleet is a plain data file, `fleet/default.nix`, mapping each machine to its role and client public key.
The ssh module reads it, looks this machine up by hostname, and derives the authorized set, so a machine's own configuration never names another's key.

The role policy is one attribute set: a workstation authorizes workstation keys alone, a server authorizes both.
Only `neogaia` exists, so the server half cannot be exercised by the real fleet.
It was verified by temporarily adding a synthetic server and a second workstation, evaluating the authorized set with `neogaia` as a workstation and again as a server, and reverting.
A workstation excluded the server's key; a server admitted all three.

Two assertions guard the derivation.
One rejects a machine absent from the fleet or carrying a role no policy defines.
The other rejects any fleet entry whose role is undefined, because such an entry matches no policy and would lose its access everywhere without failing anything.
Both were confirmed to fire.

Home-manager's `matchBlocks` is deprecated in favour of `settings`, so the client uses the latter.
`enableDefaultConfig = false` drops home-manager's own default directives, leaving the generated `~/.ssh/config` at two lines and every other directive at the value OpenSSH itself ships.

Manual confirmation was performed after a `nixos-rebuild switch`.
The secret materialized as `-r--------` owned by the primary user, and the public half derived from it matches the committed fleet entry.
The hand-placed `~/.ssh/id_ed25519` was moved aside for the test, so both directions were exercised against the decrypted secret alone: `ssh -v` to the remote reported `Server accepts key: /run/secrets/ssh-user-ed25519-key`, and an inbound connection to `neogaia` authenticated and returned a shell.

One follow-up is outstanding.
Deleting the now-redundant `~/.ssh/id_ed25519` and its public half was refused by the agent's permission layer, so both files remain on the machine.
They are superseded rather than needed: the same key is in `secrets/neogaia.yaml`, and the client is pointed at the decrypted path.
Removing them is a one-line manual step, and the key is recoverable from the secrets file if it is ever wanted back.
