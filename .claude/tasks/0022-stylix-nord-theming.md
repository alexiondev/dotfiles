---
spec: hyprland-desktop
blocked-by: 0021-desktop-group-and-hyprland-session
---

## What to build

Theme the whole new graphical layer Nord from a single source, and set the wallpaper.

Add Stylix as a flake input and a desktop theming module that drives colors, system fonts, and cursor from one Nord base16 scheme across the graphical surface (GTK, Qt, and the compositor colors), plus a single static Nord wallpaper set by Stylix.
Scope Stylix to the graphical layer only: leave its targets for the existing terminal tools (nvim, tmux, fish) off so their established hand-themes stand unchanged.
The theming is reversible per target, so individual surfaces can migrate toward or away from manual theming later.

## Acceptance criteria

- [ ] Stylix is a flake input, wired into the host build.
- [ ] A desktop theming module resolves a single Nord base16 scheme and applies it to GTK, Qt, cursor, and system fonts.
- [ ] A single static Nord wallpaper is set by Stylix; no dynamic, animated, or cycling wallpaper.
- [ ] Stylix targets for nvim, tmux, and fish are off, leaving their existing themes untouched.
- [ ] neogaia builds green under `nix flake check`, and an eval probe confirms the resolved scheme is Nord.
