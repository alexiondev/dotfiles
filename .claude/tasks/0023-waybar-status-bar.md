---
spec: hyprland-desktop
blocked-by: 0021-desktop-group-and-hyprland-session
---

## What to build

A Waybar status bar that reads system state at a glance.

Add a Waybar module to the desktop group, enabled through the aggregator, showing workspaces with per-application icons plus a clock, battery, network, audio, MPRIS media controls, and a do-not-disturb toggle.
No overview/exposé plugin: the workspace indicators are sufficient.
The do-not-disturb toggle and media controls live in the bar rather than in a separate notification center.

## Acceptance criteria

- [ ] A Waybar module exists in the desktop group and is enabled by the aggregator.
- [ ] The bar shows workspaces with per-application icons, a clock, battery, network, audio, MPRIS media controls, and a do-not-disturb toggle.
- [ ] No overview/exposé plugin is used.
- [ ] neogaia builds green under `nix flake check`.
