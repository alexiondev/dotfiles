---
spec: hyprland-desktop
blocked-by: 0021-desktop-group-and-hyprland-session
---

## What to build

Notification toasts with do-not-disturb and history recall, so missed notifications can be retrieved.

Add a mako module to the desktop group, enabled through the aggregator, rendering notification toasts with a do-not-disturb mode and history recall.
The do-not-disturb toggle and media controls live in the bar, not in a separate notification-center panel.

## Acceptance criteria

- [ ] A mako module exists in the desktop group and is enabled by the aggregator.
- [ ] Notification toasts appear, with do-not-disturb and history recall.
- [ ] No separate slide-out notification-center panel is added.
- [ ] neogaia builds green under `nix flake check`.
