---
spec: hyprland-desktop
blocked-by: 0021-desktop-group-and-hyprland-session
---

## What to build

A search-everything launcher, so one keybound tool handles launching and utility menus.

Add a rofi (Wayland fork) module to the desktop group, enabled through the aggregator, combining application-run, binary-run, and window-switch into one prompt, plus math-evaluation and emoji modes.
Bind it on `Super+R`.
Structure it so it is reusable as the dmenu-style frontend for later utility menus (clipboard history, power menu), and provide a power menu that uses it.

## Acceptance criteria

- [ ] A rofi module exists in the desktop group and is enabled by the aggregator.
- [ ] rofi combines application-run, binary-run, and window-switch modes, plus math evaluation and emoji.
- [ ] rofi opens on `Super+R`.
- [ ] rofi is usable as a dmenu-style frontend for utility menus, and a power menu is provided through it.
- [ ] neogaia builds green under `nix flake check`.
