---
spec: guests
---

## What to build

A new bundle Module, `modules.toolkit`, that turns on the baseline interactive environment — fish, tmux, nvim, git, and direnv — as one unit.
Enabling it on a Host brings up all five together, so any Host or Guest shell feels identical.
This is a deliberate bundle wanted as a unit, distinct from the grouping-directory aggregate enables ADR 0004 rejected.

## Acceptance criteria

- [x] `modules.toolkit` declares an `enable` option following the Enable convention and lives at a path its file location mirrors, per the Namespace convention.
- [x] Enabling `modules.toolkit` turns on fish, tmux, nvim, git, and direnv as a group.
- [x] A Host that enables `modules.toolkit` still reads as a flat checklist — the bundle is one line, not a hidden group of five.
- [x] A Host enabling `modules.toolkit` builds via `nix flake check`, and the five underlying Modules are enabled (verifiable by `nix eval` of their `enable` values).

## Implementation Notes

- `modules/toolkit.nix` follows the sanctioned aggregator pattern of `modules/desktop/desktop.nix`: an index node whose `enable` sets each member's `enable = lib.mkDefault true`, so a Host can still override any single piece while the one flag brings up the bundle.
- `neogaia` was converted as the demonstrating Host: its five individual `modules.{fish,git,direnv,tmux,nvim}.enable = true` lines collapse to one `modules.toolkit.enable = true`.
- The bundle also sets `modules.fish.defaultShell`, so fish is the login shell wherever the toolkit is enabled — part of making any Host or Guest shell feel identical. This is `mkDefault`, so a Host can still opt out. `neogaia`'s previously explicit `defaultShell` line is therefore dropped.
- Verified: `nix flake check` builds `checks.x86_64-linux.neogaia`, and `nix eval` of each of the five members' `enable` on neogaia returns `true`.
- The working tree also carries `.claude/CONTEXT.md`, ADR 0006, and the `guests` spec — planning artifacts for the wider `guests` spec, not this task. They are deliberately left out of this task's commit and staged separately by the broader work.
