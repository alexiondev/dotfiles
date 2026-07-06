---
spec: dot-setup-folders
blocked-by: 0011-folders-unconditional-merge
---

## What to build

Stop reading the short-name target from `~/.config/user-dirs.dirs` and
hardcode the legacy-name -> short-name mapping directly in
`_dot_setup_folders`, dropping the dependency on that file entirely.

The original design treated the tracked `user-dirs.dirs` as the single
source of truth for target names, assuming someone would hand-edit it to
the short names before ever running the command. On this machine that
never happened: the tracked file still had the stock XDG defaults
(`XDG_DOCUMENTS_DIR="$HOME/Documents"`, etc.), so `target_path` resolved to
the exact same directory as `legacy_path` for every folder. The migration
logic then reported every entry as a "collision" against itself instead of
moving anything -- a confusing, silent-feeling failure rather than an
actual migration.

The short names are fixed (`.desktop`, `doc`, `dwn`, `mus`, `pic`, `vid`,
`.ignoreme`) and not meant to be configurable, so there's nothing to read
from a file in the first place. `user-dirs.dirs` remains a separate,
manually tracked dotfile (edited and tracked by hand, like any other
dotfile) for apps/`xdg-user-dirs-update` to consult -- `dot setup folders`
itself no longer reads it, requires its presence, or writes to it.

## Acceptance criteria

- [x] `_dot_setup_folders` no longer reads, parses, or requires
      `~/.config/user-dirs.dirs`; the legacy->short-name mapping is a fixed
      table in the function itself
- [x] Migration works identically whether `user-dirs.dirs` is absent,
      empty, or declares stale/full-name values (the exact real-world case)
- [x] `user-dirs.dirs` is left byte-for-byte untouched by `dot setup
      folders` when present, and no file is created when absent
- [x] `dot setup folders help` no longer describes reading target names
      from `user-dirs.dirs`
- [x] `~/.config/dot/tests/dot.fish` no longer seeds a `user-dirs.dirs`
      fixture as a migration precondition, and covers the stale/missing
      cases above; `fishtape ~/.config/dot/tests/dot.fish` passes

## Implementation Notes

- Replaced the `xdg_vars`/`grep`/`string match` parsing of `user-dirs.dirs`
  with two parallel hardcoded arrays, `legacy_names` and `target_names`,
  indexed together -- same shape the code already used for `legacy_names`
  alone, just extended to cover the target side too.
- The early `if not test -f $user_dirs; return 1` guard was deleted outright
  rather than kept as a soft check: there's nothing left for the function to
  read from that file, so requiring its existence would just be a
  vestigial, unjustifiable precondition.
- Removed the `short_name_user_dirs` fixture and its seeding step from every
  test scenario (it was previously duplicated into ~15 scenarios as a
  migration precondition); added two new scenarios instead: one reproducing
  the exact real-machine bug (stale full-name `user-dirs.dirs` values) and
  one confirming migration works with no `user-dirs.dirs` file at all.
- Verified against this machine's real, still-stale `~/.config/user-dirs.dirs`
  via `_dot_setup_folders --dry-run`: previously reported every entry in
  Desktop/Documents/Downloads/Pictures/Videos as a collision against
  itself; now correctly reports `would move N entries from ~/Documents to
  ~/doc` etc.
- `fishtape ~/.config/dot/tests/dot.fish` passes (183 tests).
