---
spec: hyprland-desktop
blocked-by: [0023-waybar-status-bar, 0025-mako-notifications]
---

## What to build

A keybound screen recorder that selects a region and then toggles recording.

Add a wf-recorder module to the desktop group, enabled through the aggregator, that selects a region first and then toggles video-only recording (no audio), bound on `Super+Shift+R`.
Surface a recording indicator in the Waybar bar and notification toasts on start and stop.
No audio capture and no full-screen recording variant.

## Acceptance criteria

- [ ] A wf-recorder module exists in the desktop group and is enabled by the aggregator.
- [ ] The recorder selects a region first, then toggles video-only recording on `Super+Shift+R`.
- [ ] A recording indicator appears in the bar, and notifications fire on start and stop.
- [ ] No audio is captured and no full-screen variant is provided.
- [ ] neogaia builds green under `nix flake check`.
