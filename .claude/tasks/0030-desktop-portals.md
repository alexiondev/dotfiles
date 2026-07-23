---
spec: hyprland-desktop
blocked-by: 0021-desktop-group-and-hyprland-session
---

## What to build

Screen sharing that works inside applications, so video calls and browser screen-share function.

Add a portals module to the desktop group, enabled through the aggregator, wiring the Hyprland desktop portal (screencast, screenshot, global shortcuts) plus the GTK portal (file dialogs and appearance).
In-app screen sharing depends on these regardless of whether the recorder is present.

## Acceptance criteria

- [x] A portals module exists in the desktop group and is enabled by the aggregator.
- [x] The Hyprland desktop portal (screencast, screenshot, global shortcuts) and the GTK portal (file dialogs, appearance) are both configured.
- [x] In-app screen sharing is available independent of the screen recorder.
- [x] neogaia builds green under `nix flake check`.

## Implementation Notes

- **The module owns routing, not the backend packages.**
  The Hyprland compositor integration (`programs.hyprland`) already forces both portal backends into `xdg.portal.extraPortals` — `xdg-desktop-portal-hyprland` through its `portalPackage`, and `xdg-desktop-portal-gtk` through nixpkgs' `wayland-session.nix` (`enableGtkPortal` defaults on) — and turns `xdg.portal.enable` on.
  A portal backend only answers while its compositor runs, so those packages belong with the compositor and cannot be removed there; re-declaring them here would only duplicate them.
  The genuinely-missing, first-class piece was the routing: `xdg.portal.config` was empty, and which backend answered each request rode on a config file the Hyprland package happens to ship (`hyprland-portals.conf`, `default=hyprland;gtk`).
  This module makes that routing explicit and declarative.

- **Per-interface routing, not a preference list.**
  Rather than `default = [ "hyprland" "gtk" ]` (which tries Hyprland first for every interface and falls through to GTK), the three interfaces the Hyprland portal actually implements — `ScreenCast`, `Screenshot`, `GlobalShortcuts`, confirmed from its `hyprland.portal` file — are routed to Hyprland explicitly, and GTK is the default for everything else.
  This directly encodes the spec's split (Hyprland for the screen-facing requests, GTK for file dialogs and appearance) and keeps appearance on GTK even if a future Hyprland portal starts implementing `org.freedesktop.impl.portal.Settings`.

- **Already functional, now first-class.**
  Because the compositor integration already supplied both backends and a working shipped route, in-app screen sharing was effectively working before this task as an implicit side-effect.
  The deliverable is the explicit, aggregator-enabled `modules.desktop.portals` module, so the desktop's checklist reads completely and screen sharing no longer depends on a package's incidental default.
  Verified: the built config emits `/etc/xdg/xdg-desktop-portal/portals.conf` with `default=gtk` plus the three Hyprland routes, and neogaia's toplevel builds green.
