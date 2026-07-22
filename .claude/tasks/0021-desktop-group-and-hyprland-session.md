---
spec: hyprland-desktop
---

## What to build

The tracer bullet for the whole desktop: a keyboard-driven Hyprland session that neogaia can log into and open a terminal in.

Create the `modules/desktop/` group with an explicit aggregator, guarded by its own `modules.desktop.enable`, that hand-lists and turns on each piece at default priority so a host enables the whole desktop with one flag yet can still override any single piece.
Namespace every desktop enable under one desktop group so a host's checklist gains one entry.
Place the tightly coupled Hyprland-native pieces (starting with the compositor) in a subdirectory within the group.

Wire Hyprland from nixpkgs: the NixOS program integration owns the session and polkit, home-manager owns the user configuration, and both share one Hyprland package so there is never a version split.
The session is launched through the universal Wayland session manager from the greeter.
Login is greetd with the tuigreet text greeter, mouse-free and lightweight.

Port the operator's KDE/i3 keybinds expressed entirely in `hjkl` and letters with no arrow or navigation-cluster keys: numbered-workspace switch and move, focus and window movement, resize, terminal, floating, fullscreen, split, close, and force-kill, per the spec's keybind table.
Tune input: US-only layout with no switcher, Caps mapped to Escape with Shift+Caps still producing CapsLock, snappy key-repeat, touchpad tap-to-click plus natural scroll plus disable-while-typing, and flat mouse acceleration.
Set the feel: subtle animations, modest rounding, small gaps, and blur off (left as a knob a host such as zeus can enable).
Install Ghostty as the terminal on `Super+Return`.

Enable the desktop on neogaia.

## Acceptance criteria

- [ ] `modules/desktop/` exists with an aggregator exposing `modules.desktop.enable` that hand-lists and enables its pieces at default priority, each piece independently overridable.
- [ ] Desktop enable options are namespaced under a single desktop group; the Hyprland-native compositor lives in a subdirectory of the group.
- [ ] Hyprland is sourced from nixpkgs; the NixOS integration and the home-manager user config share one Hyprland package.
- [ ] The session launches through the universal Wayland session manager from a greetd/tuigreet text login.
- [ ] Keybinds match the spec's table, using only `hjkl`, letters, and number rows — no arrow or navigation-cluster keys.
- [ ] Input is tuned: US-only layout, Caps→Escape (Shift+Caps = CapsLock), snappy key-repeat, touchpad tap-to-click + natural scroll + disable-while-typing, flat mouse acceleration.
- [ ] Animations, rounding, and small gaps are on; blur is off and remains host-overridable.
- [ ] Ghostty opens on `Super+Return`.
- [ ] neogaia enables `modules.desktop` and builds green under `nix flake check`.
