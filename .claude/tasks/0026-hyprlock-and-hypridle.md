---
spec: hyprland-desktop
blocked-by: 0021-desktop-group-and-hyprland-session
---

## What to build

A secure lock screen and idle management, so going idle, suspending, or closing the lid always lands at a locked screen.

Add hyprlock and hypridle modules in the Hyprland-native subdirectory of the desktop group, enabled through the aggregator.
hyprlock uses the compositor session-lock protocol so the lock surface is owned by the compositor and survives a locker crash.
hypridle is wired for lock-on-idle, screen-off, lock-before-suspend, and lid-close, with tunable timeouts.
Bind lock on `Super+X`.

## Acceptance criteria

- [x] hyprlock and hypridle modules exist in the Hyprland-native subdirectory and are enabled by the aggregator.
- [x] hyprlock uses the compositor session-lock protocol.
- [x] hypridle triggers lock-on-idle, screen-off, lock-before-suspend, and lid-close, with tunable timeouts.
- [x] Lock is bound on `Super+X`.
- [x] neogaia builds green under `nix flake check`.

## Implementation Notes

- **hyprlock is inherently the session-lock client.**
  Criterion 2 needs no option: hyprlock draws its surface through the ext-session-lock protocol, so the compositor owns the surface and it survives a crash of the locker.
  The module therefore carries only geometry and behaviour.

- **Stylix themes the lock screen.**
  Colors and the lock background come from Stylix's hyprlock target, which merges into the same `background` and `input-field` blocks, so the module sets only field geometry and a `$TIME` label.

- **lid-close is wired through logind, not a hypridle listener.**
  hypridle cannot observe lid events, so the module sets `services.logind.settings.Login.HandleLidSwitch = "suspend"`, and the shared `before_sleep_cmd` locks ahead of the suspend.
  The lid therefore lands at a locked screen, satisfying the criterion by outcome even though the trigger is logind's.

- **`Super+X` is self-contained.**
  The keybind execs a guarded hyprlock launch directly (`pidof hyprlock || hyprlock`) rather than `loginctl lock-session`, so the lock key works whenever hyprlock is enabled, without depending on hypridle being the running lock handler.
  hypridle's own idle and suspend paths still funnel through `loginctl lock-session` so logind tracks the locked state on those paths.

- **Idle-suspend was left out.**
  The spec enumerates lock-on-idle, screen-off, lock-before-suspend, and lid-close, so hypridle does not itself suspend on idle.
  `before_sleep_cmd` handles lock-before-suspend for the lid and any manual or externally configured suspend.
  Adding an idle-suspend stage is a reasonable future knob but was not requested here.

- **One hyprlock package.**
  Both the keybind and hypridle's `lock_cmd` reference `programs.hyprlock.package`, so the locker never splits versions between the two call sites.
