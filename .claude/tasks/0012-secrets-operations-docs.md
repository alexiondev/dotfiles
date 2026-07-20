---
spec: sops-secrets
blocked-by: [0010-sops-skeleton-and-password, 0011-neogaia-ssh-host-keys]
---

## What to build

A thorough revision of the install document, not an appendix to it.

The existing procedure is built around a login password set by hand through `nixos-enter` after the install and never committed.
That step no longer exists, so the parts of the document that describe it are wrong rather than merely incomplete: the framing that names two hand-entered secrets, the step that sets the bootstrap password, the reboot step's instruction to log in with it, and the closing follow-up section — which additionally describes the superseded key-derivation mechanism as the reason sops wiring cannot happen during an install.
The LUKS passphrase remains the one secret genuinely entered by hand, and the revised document should say so plainly.

The install ordering inverts.
A host's identity is now provisioned and registered *before* its first boot, because the login password arrives only from a decrypted secret and there is no fallback credential — a first boot without a registered identity has no way in.
The document should carry that as the reason, since it is the whole point of the reordering.

Cover four procedures:

- Provisioning a host that is already installed and running, done live on the machine: generate the identity, add its recipient, re-key the affected files with the admin identity, rebuild. No reimage, no live ISO.
- Provisioning a host that does not yet exist, done on the live ISO before the install: generate the identity, add its recipient, re-key, write the identity onto the target root, then install. The install builds from a local clone, so no push is required mid-procedure; the recipient change is committed afterward.
- The editing workflow: which secrets the workstation can change on its own, and which require unlocking the admin identity for the session. That friction is intended, not an oversight.
- Recovery from a live ISO for a machine whose identity was provisioned wrongly, so a failed first boot is a known procedure rather than an improvised one.

Everything goes in the existing install document; no new document is introduced.

## Acceptance criteria

- [x] No step remains that sets a login password by hand, and nothing instructs the operator to log in with one
- [x] The document's framing names the LUKS passphrase as the only hand-entered secret
- [x] The install ordering places identity provisioning before first boot, and states why there is no fallback credential
- [x] The closing section no longer describes deriving identities from SSH host keys or defers sops wiring to a post-boot follow-up
- [x] Live provisioning for an already-running host is documented
- [x] Pre-install provisioning on the live ISO for a not-yet-existing host is documented, including that the recipient change is committed after the install
- [x] The editing workflow is documented, distinguishing what the workstation can re-key alone from what needs the admin identity
- [x] The live-ISO recovery path for a wrongly-provisioned machine is documented
- [x] The document reads end to end as one coherent procedure for a reader who has never seen the previous version

## Implementation Notes

**The document was retitled and given a table of contents.**
Three of the four procedures are not installs, so "Installing `neogaia`" no longer described the contents.
It is now "Installing and provisioning a host", and the install procedure is one section among four rather than the whole document.
The install steps stay concrete about `neogaia` and its NVMe device, since that is the only machine the flake installs today and a generic example would be less useful than a real one.

**Commands were verified against the running system rather than written from memory.**
Neither `sops` nor `age` is packaged by this flake, so every invocation goes through `nix run nixpkgs#sops` or `nix shell nixpkgs#age -c age-keygen`, and the document says so up front.
`sops updatekeys`, `age-keygen -y`, and `nixos-install --root/--flake/--no-root-password` were each confirmed to exist.
The identity file's `0400 root:root` and `/var/lib/sops-nix/key.txt` were read off the live machine, and `/var` was confirmed to sit on the `@root` subvolume, which is what makes the path valid before user creation.

**Review caught four factual errors, all corrected.**
The most consequential: the post-provisioning check said `ls -l /run/secrets/`, but `neededForUsers` puts the password hash in `/run/secrets-for-users/` — confirmed by `nix eval`, which returns `/run/secrets-for-users/alexion-password`.
The one secret whose failure causes the lockout the document exists to prevent was the one the reader was told not to look at.
Also fixed: the `.sops.yaml` example added a new host to the shared rule but not a rule for its own file, which makes `sops` refuse it with `no matching creation rules found`; step 8's `updatekeys` omitted `SOPS_AGE_KEY_FILE`, so it would have looked in `~/.config/sops/age/keys.txt` rather than the root-owned identity; and "create its file now" did not say that a host enabling the SSH daemon needs `ssh-host-<type>-key` entries or the build fails at evaluation.

**Deliberate redundancy in the recovery path.**
Review flagged the disko remount block and the re-key sequence as duplicated between the install and recovery sections.
They are left duplicated on purpose: an operator running the recovery procedure is locked out of the machine, and sending them to page back into the install steps mid-recovery is worse than the maintenance cost of two copies.
The already-running-host procedure does cross-reference step 4, because that reader has a working machine and can follow a link.

**The recovery procedure is documented but unexercised.**
Both branches follow from verified facts — `nixos-install` is idempotent and reuses the formatted disk, and the secrets file is baked into the closure at build time, which is why one branch needs a rebuild and the other does not.
Neither has been run, because doing so requires deliberately locking out the only machine.
The claim that no fallback credential exists was checked rather than assumed: there is no `authorizedKeys`, no root password, and `mutableUsers = false`.

**Follow-up.**
Task 0019 adds user SSH keys, which will make "no authorized SSH key" in the no-fallback paragraph stale.
That paragraph is the place to revisit when it lands, since an authorized key would become a genuine second way in.
