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

- [ ] `neogaia` has its own client SSH identity, distinct from its host keys, adopted from the key already on the machine
- [ ] Its private half is stored in `neogaia`'s own secrets file, encrypted to the admin identity and `neogaia` alone
- [ ] Its public half is committed in plaintext
- [ ] The private half decrypts at activation, readable only by the primary user and not by other accounts
- [ ] The SSH client uses the decrypted key with no hand-placed copy in the user's home directory
- [ ] Each machine declares a role, and the keys it authorizes follow from that role rather than from a per-host list
- [ ] Workstation keys are authorized on every machine
- [ ] Server keys are authorized on servers only, and on no workstation
- [ ] Registering a new machine is a role declaration in one place, requiring no edit to any other host
- [ ] `nix flake check` builds the `neogaia` toplevel
- [ ] Manual confirmation: the key materializes with the declared ownership and mode, an authenticated push to the remote still succeeds, and `neogaia` accepts an SSH connection offering the adopted key
