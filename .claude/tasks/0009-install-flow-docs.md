---
spec: laptop-mvi
blocked-by: [0002-neogaia-disk-and-boot, 0003-kernel-and-hardware, 0004-networking-and-base-system, 0005-fish-shell-module, 0006-tmux-module, 0007-nvim-module, 0008-claude-code-module]
---

## What to build

Document the one-shot install procedure that turns the completed `neogaia` `Host` into a running encrypted laptop from the NixOS live ISO — the capstone, written once every functional slice is in place so it describes the actually-complete `Host`.

The procedure: push the repo to Gitea first; from the live ISO, join wifi, clone the repo locally (avoiding self-signed-TLS/auth problems with flake fetching during install), and run `disko-install` against the `neogaia` `Host` with the chaotic substituter passed to the install-time Nix daemon (or it compiles the CachyOS kernel from source on the USB stick). Then set the bootstrap password by hand via `nixos-enter` — never committed to the public repo — and reboot.

Note the bootstrap ordering (the flake must exist on Gitea before the install can consume it) and that moving the password to a `hashedPasswordFile` backed by a sops secret is the first post-boot task, out of scope here (per ADR 0001, an age key does not exist until the first install generates the SSH host key).

## Acceptance criteria

- [x] The install procedure is documented end to end: push to Gitea → join wifi on the live ISO → clone locally → `disko-install` against `neogaia` → set bootstrap password via `nixos-enter` → reboot.
- [x] The docs state that the install-time Nix daemon must have the chaotic substituter configured, or the kernel compiles from source on the USB stick.
- [x] The docs explain that the local clone avoids self-signed-TLS/auth problems with flake fetching during install.
- [x] The bootstrap password is set by hand and never committed; the docs flag the sops-backed `hashedPasswordFile` migration as the first post-boot follow-up.

## Implementation Notes

The runbook lives at `docs/install.md`.

Every documented command was checked against the actual pinned tooling rather than written from memory:

- The `disko-install` and `disko` flags (`--flake`, `--disk NAME DEVICE`, `--write-efi-boot-entries`, `--option`, `--mode mount`) were read out of the pinned disko revision's wrapped scripts (the disko rev in `flake.lock`).
- A consequence surfaced there and shaped the doc: `disko-install` traps `EXIT` and **unmounts** the target, so the "set the bootstrap password" step must first remount with `disko --mode mount` before `nixos-enter`.
  A naive `nixos-enter --root /mnt` straight after the install would have found nothing mounted.
- The chaotic substituter URL and trusted key are quoted verbatim from `system/default.nix`, and `--disk main /dev/nvme0n1` matches `hosts/neogaia/disk.nix`.

Two secrets are set by hand at install time, not one: the doc distinguishes the **LUKS passphrase** (prompted by disko at format, typed at every boot) from the **bootstrap login password** (set via `nixos-enter passwd`).
The task named only the login password; the LUKS passphrase is an unavoidable part of the same by-hand flow, so it is documented alongside for a complete runbook.

Beyond the task's terse list, the doc adds: a minimal-vs-graphical ISO split for joining wifi, and — from review — an SSH-key caveat for the clone plus an HTTPS-with-`sslVerify=false` fallback (which also reinforces the "git can skip verification where the flake fetcher can't" point behind the local-clone requirement).
No criteria were dropped.
