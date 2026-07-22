---
spec: hyprland-desktop
blocked-by: 0021-desktop-group-and-hyprland-session
---

## What to build

Keyboard-driven screenshots that open in an annotation editor by default and land in both the clipboard and a file.

Add a screenshot module to the desktop group, enabled through the aggregator, using grim and slurp wrapped by grimblast and routed through the satty annotation editor so annotation is the default.
Cover region, active-window, and full-screen captures, each exporting to both the clipboard and a file.
Bind region on `Super+L`, active window on `Super+Shift+L`, and full screen on `Super+Ctrl+L`.

## Acceptance criteria

- [ ] A screenshot module exists in the desktop group and is enabled by the aggregator.
- [ ] Region, active-window, and full-screen captures work, each opening in satty and exporting to both clipboard and file.
- [ ] Captures are bound on `Super+L`, `Super+Shift+L`, and `Super+Ctrl+L`.
- [ ] neogaia builds green under `nix flake check`.
