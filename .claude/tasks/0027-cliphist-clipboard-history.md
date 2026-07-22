---
spec: hyprland-desktop
blocked-by: 0024-rofi-launcher
---

## What to build

Clipboard history picked entirely by keyboard.

Add a cliphist module (with wl-clipboard) to the desktop group, enabled through the aggregator, storing both text and image history and picked through rofi.
Bind the picker on `Super+Shift+V`.

## Acceptance criteria

- [ ] A cliphist module (with wl-clipboard) exists in the desktop group and is enabled by the aggregator.
- [ ] Text and image copies are recorded to history.
- [ ] The history is picked through rofi and bound on `Super+Shift+V`.
- [ ] neogaia builds green under `nix flake check`.
