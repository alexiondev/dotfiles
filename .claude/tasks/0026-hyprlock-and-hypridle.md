---
spec: hyprland-desktop
blocked-by: 0021-desktop-group-and-hyprland-session
---

## What to build

A secure lock screen and idle management, so going idle, suspending, or closing the lid always lands at a locked screen.

Add hyprlock and hypridle modules in the Hyprland-native subdirectory of the desktop group, enabled through the aggregator.
hyprlock uses the compositor session-lock protocol so the lock surface is owned by the compositor and survives a locker crash.
hypridle is wired for lock-on-idle, screen-off, lock-before-suspend, and lid-close, with tunable timeouts.
Bind lock on `Super+X`.

## Acceptance criteria

- [ ] hyprlock and hypridle modules exist in the Hyprland-native subdirectory and are enabled by the aggregator.
- [ ] hyprlock uses the compositor session-lock protocol.
- [ ] hypridle triggers lock-on-idle, screen-off, lock-before-suspend, and lid-close, with tunable timeouts.
- [ ] Lock is bound on `Super+X`.
- [ ] neogaia builds green under `nix flake check`.
