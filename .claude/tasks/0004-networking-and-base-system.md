---
spec: laptop-mvi
blocked-by: 0001-skeleton-and-building-host
---

## What to build

Make the booted laptop a usable console I can log into and reach remotely: NetworkManager for joining wifi, an SSH daemon for driving the rest of the setup over the network, and the base locale settings.

Set timezone `America/New_York`, locale `en_GB.UTF-8`, and console keymap `us`.

## Acceptance criteria

- [x] NetworkManager is enabled so wifi can be joined from the console.
- [x] An SSH daemon is enabled so the machine can be driven remotely.
- [x] Timezone is `America/New_York`, locale is `en_GB.UTF-8`, console keymap is `us`.
- [x] The `neogaia` toplevel still builds with all of the above.

## Implementation Notes

- **Placement in the Host, not a Module.** NetworkManager, the SSH daemon, and the locale/timezone/keymap settings all live directly in `hosts/neogaia/default.nix`, alongside the kernel/hardware/zram lines from task 0003.
  This follows the precedent set in that task, where a speculative enable-gated Module was dropped in review in favour of inlining for the single-Host MVI.
  A shared locale Module or a networking Module can be extracted later when a second Host actually needs the same settings; extracting now would be speculative generality.
- **SSH left unhardened deliberately.** `services.openssh.enable = true` keeps NixOS's default password authentication on.
  This is required by the install flow: first-boot access is over SSH with the hand-set bootstrap password, and no SSH keys or sops-derived age key exist until the install generates the Host's SSH host key.
  Moving to key-only auth / `hashedPasswordFile` is the first post-boot follow-up per the spec's Secrets section, out of scope for the MVI.
- **Locale/timezone mix is as specified.** `i18n.defaultLocale = "en_GB.UTF-8"` with `time.timeZone = "America/New_York"` and `console.keyMap = "us"` mixes region and locale; this matches the operator's stated preferences verbatim and is intentional.
- **Verification.** Built the primary seam — `nix build .#checks.x86_64-linux.neogaia` (the Host toplevel) — to exit 0; the systemd units for `wpa_supplicant` (NetworkManager's backend) and openssh appear in the build. The five option values were also confirmed via `nix eval`.
