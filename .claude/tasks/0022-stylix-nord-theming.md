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

- [x] Stylix is a flake input, wired into the host build.
- [x] A desktop theming module resolves a single Nord base16 scheme and applies it to GTK, Qt, cursor, and system fonts.
- [x] A single static Nord wallpaper is set by Stylix; no dynamic, animated, or cycling wallpaper.
- [x] Stylix targets for nvim, tmux, and fish are off, leaving their existing themes untouched.
- [x] neogaia builds green under `nix flake check`, and an eval probe confirms the resolved scheme is Nord.

## Implementation Notes

- **Wallpaper is a generated Nord gradient, not a shipped image.**
  Stylix requires an `image`, and the spec asks only for "a single static Nord wallpaper".
  Rather than commit a binary blob or fetch one over the network at build time, the module draws a vertical gradient across the Nord Polar Night shades (`#2E3440` → `#3B4252`) with ImageMagick.
  It is static, genuinely Nord, and fully reproducible with no external dependency beyond a cached build tool.
  Swapping in a picture later is a one-line change to `image`.

- **The nvim target is `nixvim`, not `neovim`.**
  nvim here is configured through nixvim, so the Stylix target that would theme it is `nixvim`.
  Disabling `neovim` would have been a no-op and left nvim themed.

- **fish is disabled at two levels.**
  fish is enabled both at system level (`programs.fish`, for `/etc/shells` and vendor completions) and in home-manager, so its theming has a target in each scope.
  Both are turned off, so the hand-written fish theme stands.

- **Cursor generation switched on explicitly.**
  home-manager now wants `home.pointerCursor.enable` set explicitly rather than inferring it from the presence of cursor settings, so the module sets it to silence the deprecation and keep the build warning-clean (bar the pre-existing benign nixvim `nixpkgs.follows` notice).

- **System font pinned to JetBrains Mono.**
  The acceptance criterion asks for "system fonts" without naming one, so the monospace is pinned to JetBrains Mono and the serif/sans/emoji families are left at Stylix's Nord-coherent defaults.

- **Stylix module imported unconditionally.**
  `lib.nix` adds `inputs.stylix.nixosModules.stylix` to every host's module set, matching how the other input modules are wired.
  It stays inert until `stylix.enable` is set, which only the theming module does, only when the desktop is on.
