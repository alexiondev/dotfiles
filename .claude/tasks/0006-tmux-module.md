---
spec: laptop-mvi
blocked-by: 0001-skeleton-and-building-host
---

## What to build

A tmux `Module`, configured natively via home-manager, that reproduces the current terminal multiplexer exactly: the existing `tmux.conf` text (under `reference/home/.config/tmux/`) inlined verbatim, with no plugin manager needed.

## Acceptance criteria

- [x] A tmux `Module` (following the `Enable convention`) is enabled on `neogaia` and configured natively via home-manager.
- [x] The existing `tmux.conf` text is inlined verbatim, producing an identical configuration to today.
- [x] No tmux plugin manager is used.
- [x] The `neogaia` toplevel still builds with the tmux `Module` enabled.

## Implementation Notes

**Approach — option translation ("the nix way") instead of byte-verbatim inlining.**
On the operator's explicit call ("I would prefer to do things the nix way. It's okay if the config file doesn't match"), the settings home-manager's `programs.tmux` exposes as options are set as options (`prefix`, `keyMode`, `mouse`, `baseIndex`, `clock24`, `escapeTime`, `historyLimit`, `terminal`), and only the settings it has *no* option for are inlined verbatim, read from `modules/tmux/extra.conf` via `builtins.readFile`.
The generated `~/.config/tmux/tmux.conf` is therefore **behaviourally** identical to today, not byte-identical: home-manager prepends its own option-derived lines.
This was preferred over `xdg.configFile.source = ./tmux.conf` (which would have been byte-identical) after weighing both.
Verified end-to-end by having a live tmux binary parse the generated config: `prefix=C-Space base-index=1 mode-keys=vi clipboard=on hist=10000 clock=24`, zero parse errors.

**`clock24 = true` is required, not cosmetic.**
home-manager always emits `clock-mode-style`; `true` → 24, which matches tmux's own compiled default (what the reference config, which never sets it, gets today).
Leaving it at the module default (`false`) would have *forced* a 12-hour clock — a real deviation.

**Pane navigation stays in `extra.conf`.**
home-manager's `customPaneNavigationAndResize` option would emit the `h/j/k/l select-pane` binds, but it *also* adds `H/J/K/L` resize binds the reference config does not have.
To stay faithful, the `h/j/k/l` binds are inlined in `extra.conf` and the option is left off.

**`secureSocket` left at the home-manager default (`true`).**
The tmux socket lives under `/run` rather than `/tmp`; it does not survive logout.
This differs from stock tmux behaviour and was accepted deliberately.

**Comments in `extra.conf` rewritten to the project convention.**
The reference `tmux.conf` comments justify choices against alternatives, speculate about future setups, and reference other files — all disallowed by the CLAUDE.md comment convention.
Since `extra.conf` is authored repo config, its comments were tightened to describe only current behaviour; every tmux directive is preserved verbatim, so behaviour is unchanged.

**Version-sensitivity (not a defect today).**
`programs.tmux.sensibleOnTop` defaults to `false` at the pinned home-manager rev, so no `tmux-sensible` plugin is injected and the "no plugin manager" criterion holds.
A future home-manager bump that flipped that default would silently pull the plugin in.
