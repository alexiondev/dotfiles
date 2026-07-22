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

- [x] A rofi module exists in the desktop group and is enabled by the aggregator.
- [-] rofi combines application-run, binary-run, and window-switch modes, plus math evaluation and emoji.
- [x] rofi opens on `Super+R`.
- [x] rofi is usable as a dmenu-style frontend for utility menus, and a power menu is provided through it.
- [x] neogaia builds green under `nix flake check`.

## Implementation Notes

- `rofi-wayland` no longer exists as a separate package: nixpkgs merged the Wayland fork into `pkgs.rofi` (now 2.0.0).
  The module uses the plain `pkgs.rofi`, which is the Wayland-capable build.
- Criterion 2 is deliberately reduced (`[-]`): the launcher is application-launch only, `modi = "drun"`, opened with `rofi -show drun` on `Super+R`.
  Binary-run, window-switch, math (`rofi-calc`) and emoji (`rofi-emoji`) were all dropped at the operator's direction, and the two plugins removed with them, to keep the prompt as fast and uncluttered as possible.
  This narrows the parent spec's "search-everything launcher" (user story 7) to a plain application launcher — a reversible choice, since any mode or plugin can be added back later.
  Application icons are disabled too (`show-icons = false`), since resolving an icon per entry is the largest part of drun's per-launch startup and rofi runs no resident daemon to amortise it.
- The dmenu-style reuse is the themed rofi itself, not a separate abstraction: any `rofi -dmenu` invocation reads the same config and Stylix theme, so the power menu — and later clipboard/utility menus — look uniform for free.
- The launcher and power-menu keybinds live in this module rather than in `hyprland.nix`, contributed through `settings.bind`, which the module system concatenates with the compositor's own binds in the single `hyprland.conf`.
  This keeps each command next to its binding and referenced by store path, so a rename cannot silently break the bind.
- The power menu is bound to `Super+Shift+X`, chosen by the operator.
  It pairs with lock on `Super+X` (a key the spec's table does list), while the parent spec's table has no power-menu key of its own.
- No Waybar `window-rewrite` icon mapping was added: rofi renders as a Wayland layer-shell overlay, not a tiled window with a class on a workspace, so it never appears on the workspace indicator the convention governs.
- The launcher's quick appearance is a Hyprland change, not a rofi one: layer surfaces get their own `layersIn`/`fadeLayersIn` fade at `2`, a step quicker than the `3` windows use, so the launcher fades in without feeling laggy.
