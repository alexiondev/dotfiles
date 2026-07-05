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

- [ ] `dot setup folders` on a fresh scratch `$HOME` (all 8 legacy folders
      present and empty) renames them to their short-name targets per the
      mapping table, including `Pictures/Screenshots→pic/screenshots`, and
      leaves the tracked `user-dirs.dirs` short names in place
- [ ] The fake `xdg-user-dirs-update` (PATH-prepended, logging its invocation
      per the project's existing fake-`sudo`/fake-`pacman` testing pattern)
      is invoked exactly once after a successful migration
- [ ] Bare `dot setup` on a fresh scratch `$HOME` runs the `folders` task as
      part of running everything
- [ ] `dot setup folders help` and `dot setup help` print usage and make no
      filesystem changes
- [ ] Re-running `dot setup folders` after a clean migration is a no-op
      (idempotent)
- [ ] `~/.github/README.md` has a command-table row for `dot setup`
      (and its `folders` task) with paths relative to `$HOME`
- [ ] `~/.config/dot/tests/dot.fish` covers the above cases and
      `fishtape ~/.config/dot/tests/dot.fish` passes
