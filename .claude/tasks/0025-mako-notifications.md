---
spec: hyprland-desktop
blocked-by: 0021-desktop-group-and-hyprland-session
---

## What to build

Notification toasts with do-not-disturb and history recall, so missed notifications can be retrieved.

Add a mako module to the desktop group, enabled through the aggregator, rendering notification toasts with a do-not-disturb mode and history recall.
The do-not-disturb toggle and media controls live in the bar, not in a separate notification-center panel.

## Acceptance criteria

- [x] A mako module exists in the desktop group and is enabled by the aggregator.
- [x] Notification toasts appear, with do-not-disturb and history recall.
- [x] No separate slide-out notification-center panel is added.
- [x] neogaia builds green under `nix flake check`.

## Implementation Notes

- **Bar side already in place.**
  The do-not-disturb toggle (`custom/dnd`, calling `makoctl mode -t dnd`) and the MPRIS media controls already live in `modules/desktop/waybar.nix` from task 0024.
  This task therefore adds only the daemon: `modules/desktop/mako.nix` enables `services.mako` through home-manager and is turned on by the aggregator.
  The mode name is `dnd` on both sides, so the bar's toggle and the daemon's `[mode=dnd]` section agree.

- **Colors from Stylix.**
  Stylix ships a mako target that drives the background, border, text, and progress colors plus the popup font from the one Nord base16 scheme, so the module sets no colors — only behaviour.
  This mirrors how `rofi.nix` and `theming.nix` defer their palettes to Stylix.

- **Do-not-disturb keeps history.**
  The `[mode=dnd]` section sets `invisible=true`, which hides toasts while still recording them, so notifications missed during do-not-disturb remain retrievable.

- **History recall keybind.**
  `Super+N` runs `makoctl restore`, popping the last notification back from history keyboard-only, consistent with the rest of the session.
  `N` is unused by the spec keybind table, and task 0021 established that each later task adds its own binding rather than 0021 binding to a then-missing tool.

- **No Waybar icon mapping.**
  The window-rewrite convention covers graphical apps whose windows appear on the workspace indicator; mako renders toasts as a layer-shell overlay with no tiled window and no `hyprctl clients` entry, so there is nothing to match on.

- **Dropped from the plan.**
  A `Super+Shift+N` dismiss-all binding was drafted alongside the recall bind but removed as unrequested scope: the acceptance criteria call for history recall, which `restore` alone serves.
