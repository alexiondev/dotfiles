---
spec: hyprland-desktop
blocked-by: 0021-desktop-group-and-hyprland-session
---

## What to build

Screen sharing that works inside applications, so video calls and browser screen-share function.

Add a portals module to the desktop group, enabled through the aggregator, wiring the Hyprland desktop portal (screencast, screenshot, global shortcuts) plus the GTK portal (file dialogs and appearance).
In-app screen sharing depends on these regardless of whether the recorder is present.

## Acceptance criteria

- [ ] A portals module exists in the desktop group and is enabled by the aggregator.
- [ ] The Hyprland desktop portal (screencast, screenshot, global shortcuts) and the GTK portal (file dialogs, appearance) are both configured.
- [ ] In-app screen sharing is available independent of the screen recorder.
- [ ] neogaia builds green under `nix flake check`.
