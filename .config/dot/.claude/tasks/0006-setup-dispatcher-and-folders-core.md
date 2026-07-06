---
spec: dot-setup-folders
---

## What to build

A new `dot setup` subcommand family, following the project's existing
nested-subcommand dispatch convention. Bare `dot setup` (no arguments) runs
every machine-setup task unconditionally; `dot setup <task>` runs just that
one task. The only task that exists yet is `folders`.

`dot setup folders` brings the 8 standard XDG user directories under the
project's short-name convention (`Desktop→.desktop`, `Documents→doc`,
`Downloads→dwn`, `Music→mus`, `Pictures→pic`, `Videos→vid`, `Templates` and
`Public` both →`.ignoreme`). The desired short names live in a tracked
`user-dirs.dirs` file (a plain dotfile, not generated from a table each run).
A separate small hardcoded table maps each of the 8 standard XDG categories
to its legacy full-named folder, used only to locate content an XDG-defaults
install would have left behind, and merge it into the already-tracked
short-named target.

This slice covers the core happy path: a legacy folder found empty (strictly:
no entries at all, including dotfiles/metadata) is merged into its
short-named target silently, with no confirmation needed. As part of the same
`Pictures→pic` pass, a nested `Screenshots` folder is renamed to lowercase
`screenshots`, landing at `pic/screenshots`. After all folder moves complete,
run `xdg-user-dirs-update` (no arguments) once to notify running apps/portals.
`~/wrk` gets no XDG variable of its own and is out of scope for any mapping;
the existing ad hoc `~/Projects` folder is left alone.

Non-empty legacy folders and filename collisions are out of scope for this
slice (covered by later tasks) — for now it's acceptable for a non-empty
legacy folder to be handled in whatever minimal way unblocks the empty-folder
path (e.g. left untouched with a message), since the confirmation gate and
collision safety are built out next.

Wire the new command into the project's standard subcommand checklist: a
`_dot_setup_usage` help function reachable via `dot setup help` (and
`dot setup folders help` for the nested task), the completions/help-glob
duplication point, and a README command-table row.

## Acceptance criteria

- [x] `dot setup folders` on a fresh scratch `$HOME` (all 8 legacy folders
      present and empty) renames them to their short-name targets per the
      mapping table, including `Pictures/Screenshots→pic/screenshots`, and
      leaves the tracked `user-dirs.dirs` short names in place
- [x] The fake `xdg-user-dirs-update` (PATH-prepended, logging its invocation
      per the project's existing fake-`sudo`/fake-`pacman` testing pattern)
      is invoked exactly once after a successful migration
- [x] Bare `dot setup` on a fresh scratch `$HOME` runs the `folders` task as
      part of running everything
- [x] `dot setup folders help` and `dot setup help` print usage and make no
      filesystem changes
- [x] Re-running `dot setup folders` after a clean migration is a no-op
      (idempotent)
- [x] `~/.github/README.md` has a command-table row for `dot setup`
      (and its `folders` task) with paths relative to `$HOME`
- [x] `~/.config/dot/tests/dot.fish` covers the above cases and
      `fishtape ~/.config/dot/tests/dot.fish` passes

## Implementation Notes

- The desired short names for `dot setup folders` are read directly from the
  tracked `~/.config/user-dirs.dirs` (parsed via `grep`/`string match`, not
  sourced as shell), per the parent spec's decision that this file is the
  single source of truth. This machine's real `user-dirs.dirs` was
  deliberately left untouched/untracked and no live migration was run against
  this machine's actual home directory — the user chose "code + tests only"
  scope for this task (a real rename of `~/Desktop`, `~/Documents`, etc. is a
  separate, explicit action to take later), so only the scratch-`$HOME`
  fishtape fixtures exercise the short-name `user-dirs.dirs` content.
  Tracking the real file and running the real migration remains open.
- During `/review-uncommitted`, the spec-fidelity pass caught a real bug: the
  nested `Pictures/Screenshots→pic/screenshots` move ran unconditionally,
  before checking whether `Pictures` held other, unrelated content — so a
  `Pictures` folder with both `Screenshots/` and some other file got
  partially mutated (Screenshots pulled out) while still being reported as
  "left in place." Fixed by gating the Screenshots move on the rest of the
  folder being empty too; added a regression test for this case
  ("Screenshots is not peeled off... when Pictures still has other
  content").
- Completions (`~/.config/fish/completions/dot.fish`) got a `dot setup`
  block mirroring `dot kde`'s per-subcommand completion entries, even though
  the task's required "completions/help-glob duplication point" is already
  satisfied automatically by the existing generic directory glob (no changes
  were needed there for `dot setup`/`dot help` to discover the new nested
  command). The added completions are a small polish addition beyond the
  strict letter of the acceptance criteria, consistent with the existing
  `kde` subcommand's treatment.
