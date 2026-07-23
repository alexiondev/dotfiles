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

- [x] A wf-recorder module exists in the desktop group and is enabled by the aggregator.
- [x] The recorder selects a region first, then toggles video-only recording on `Super+Shift+R`.
- [x] A recording indicator appears in the bar, and notifications fire on start and stop.
- [x] No audio is captured and no full-screen variant is provided.
- [x] neogaia builds green under `nix flake check`.

## Implementation Notes

- **Toggle design.**
  One key both starts and stops.
  A running capture is stopped with SIGINT so wf-recorder finalises the file; otherwise slurp picks a region and wf-recorder runs in the foreground for the whole recording, so the same invocation fires the "saved" notification once the file is written.
  Region-first and video-only (no `-a`, so no audio) satisfy the spec directly, and no full-screen variant is offered.

- **Bar indicator polls rather than signals.**
  The Waybar `custom/recording` widget samples the wf-recorder process with `pgrep` on a one-second interval, showing a video glyph while a capture runs and collapsing to nothing when idle.
  An earlier draft signalled Waybar (`pkill -RTMIN+9`) from the toggle, but the start path raised the signal before wf-recorder had launched, so `pgrep` saw nothing and the indicator never lit during a recording — caught in review.
  Polling is race-free, removes the signal number shared across two files, and is adequate for a status glyph.

- **No waybar `window-rewrite` icon.**
  wf-recorder is headless and slurp is a transient selection overlay, so neither owns a workspace window and the per-application icon convention does not apply.

- **Output paths follow XDG user-dirs.**
  A new `modules.desktop.userdirs` declares the XDG user directories (home-manager `xdg.userDirs`), and the recorder resolves its base with `xdg-user-dir VIDEOS`, writing timestamped `recording-<date>.mp4` under `<Videos>/Recordings` (created on first capture).
  The screenshot module (task 0028) was aligned to the same convention (`xdg-user-dir PICTURES` → `<Pictures>/Screenshots`), so relocating a directory is a one-line change to `xdg.userDirs` rather than an edit in each tool.

- **Live capture is the irreducible manual step.**
  The build is green, the config parses under `Hyprland --verify-config`, and the indicator's idle/recording transitions are verified against a stand-in process; exercising a real slurp selection and wf-recorder capture needs a running session.
