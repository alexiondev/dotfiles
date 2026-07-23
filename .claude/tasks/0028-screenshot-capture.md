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

- [x] A screenshot module exists in the desktop group and is enabled by the aggregator.
- [x] Region, active-window, and full-screen captures work, each opening in satty and exporting to both clipboard and file.
- [-] Captures are bound on `Super+L`, `Super+Shift+L`, and `Super+Ctrl+L`.
- [x] neogaia builds green under `nix flake check`.

## Implementation Notes

- **Screenshot binds moved off `Super+L` to the Print key family.**
  Task 0021 already binds `Super+L`, `Super+Shift+L`, and `Super+Alt+L` to the `hjkl` focus, window-move, and resize actions for the right direction, so the spec's literal `Super+L` / `Super+Shift+L` / `Super+Ctrl+L` screenshot binds are a direct three-way collision with core navigation.
  Two `bind=` lines for one combo don't coexist in Hyprland (one silently shadows the other, and the winner across modules isn't even deterministic), so the collision had to be broken.
  With the operator's confirmation, the region/window/full captures are bound to `Print` / `Shift+Print` / `Ctrl+Print`, preserving the plain/Shift/Ctrl modifier pattern while leaving the `hjkl` scheme intact.
  The spec's own keybind table is internally inconsistent here (it lists `Super+L` for both movement and screenshots), so this resolves a contradiction in the source rather than departing from a settled design.

- **Capture pipeline.**
  `grimblast save <area|active|screen> -` captures to stdout and pipes into satty, whose copy action is configured with `--copy-command wl-copy --save-after-copy`, so one confirmation lands the shot in both the clipboard and a dated file under `~/Pictures/Screenshots`.
  `--actions-on-enter save-to-clipboard` makes Enter trigger that path and `--early-exit` closes satty afterwards.
  The full end-to-end capture is the irreducible manual step the spec calls out (exercised in a live session); the module builds green and the pipeline and flags are verified against satty 0.21.1.

- **No waybar icon for satty.**
  The repo convention adds a `window-rewrite` mapping for each graphical application, but satty is a transient floating annotation window rather than a window that lives on a workspace, so at the operator's direction it gets no workspace glyph.
