---
spec: hyprland-desktop
blocked-by: 0024-rofi-launcher
---

## What to build

Clipboard history picked entirely by keyboard.

Add a cliphist module (with wl-clipboard) to the desktop group, enabled through the aggregator, storing both text and image history and picked through rofi.
Bind the picker on `Super+Shift+V`.

## Acceptance criteria

- [x] A cliphist module (with wl-clipboard) exists in the desktop group and is enabled by the aggregator.
- [x] Text and image copies are recorded to history.
- [x] The history is picked through rofi and bound on `Super+Shift+V`.
- [x] neogaia builds green under `nix flake check`.

## Implementation Notes

- The module is named `clipboard`, not `cliphist`: cliphist is the tool it is built on, but the option a host enables names the capability.
- The two clipboard watchers are not hand-written: home-manager's `services.cliphist` module runs them as a pair of systemd user services, one for text and one for `--type image`.
  `allowImages` defaults true, so enabling the service alone records both kinds.
- That module installs only `cliphist` on PATH and reaches `wl-clipboard` by store path, so `wl-copy`/`wl-paste` are added to `home.packages` here.
  The spec asks for the module "with wl-clipboard", and a keyboard-driven session wants the two commands for piping to and from the clipboard.
- The services bind to `graphical-session.target`, which uwsm starts, matching how mako and hypridle attach to the session on this host.
  No `systemdTargets` override is needed, since the module's default already resolves to that target.
- The picker is a small shell script over the same themed rofi the launcher uses (`cliphist list | rofi -dmenu | cliphist decode | wl-copy`), so history looks like every other menu.
  Its keybind lives in this module rather than in `hyprland.nix`, contributed through `settings.bind`, keeping the command next to its binding and referenced by store path.
- No Waybar `window-rewrite` icon mapping was added: the watchers are headless daemons and the picker is a rofi layer surface, so nothing new ever appears as a tiled window on the workspace indicator the convention governs.
- Image entries render as a `[[ binary data … ]]` placeholder line in the rofi list rather than a thumbnail, but selecting one still decodes and re-copies the real image, so both kinds are retrievable.
