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

- [ ] No step remains that sets a login password by hand, and nothing instructs the operator to log in with one
- [ ] The document's framing names the LUKS passphrase as the only hand-entered secret
- [ ] The install ordering places identity provisioning before first boot, and states why there is no fallback credential
- [ ] The closing section no longer describes deriving identities from SSH host keys or defers sops wiring to a post-boot follow-up
- [ ] Live provisioning for an already-running host is documented
- [ ] Pre-install provisioning on the live ISO for a not-yet-existing host is documented, including that the recipient change is committed after the install
- [ ] The editing workflow is documented, distinguishing what the workstation can re-key alone from what needs the admin identity
- [ ] The live-ISO recovery path for a wrongly-provisioned machine is documented
- [ ] The document reads end to end as one coherent procedure for a reader who has never seen the previous version
