---
spec: dot-setup-folders
blocked-by: 0008-folders-collision-handling
---

## What to build

Remove the `--yes` confirmation gate that 0007/0008 built: a legacy folder
with real content in it is migrated unconditionally now, the same as an
empty one, since the collision handling from 0008 already makes the merge
non-destructive on its own (a same-named entry is never overwritten, and the
legacy folder is kept whenever any collision occurred). The `--yes` gate
turned out to protect against a scenario collision handling already
prevents, while making the everyday case — a machine that already has real
files in `~/Documents`, `~/Pictures`, etc. — a silent no-op unless the flag
was remembered, which defeats the point of the task.

In its place:

- `dot setup folders` always attempts the merge for every legacy folder,
  content or none.
- A new `--dry-run` flag replaces `--yes` in the flag slot: it reports what
  would move and what would be skipped as a collision, without touching the
  filesystem at all (no `mkdir`, no `mv`/`rmdir`, no `xdg-user-dirs-update`).
- A real (non-dry-run) run now reports what it moved per legacy folder
  (e.g. `moved 12 entries from ~/Documents to ~/doc`), instead of staying
  silent on success. A folder where nothing top-level moved (already empty,
  or everything in it collided) prints no such line — only non-trivial moves
  and collisions produce output.
- `--yes` is removed outright (not kept as a silent no-op): passing it now
  fails with argparse's standard unknown-option error.

## Acceptance criteria

- [x] A legacy folder with real content merges on a plain `dot setup
      folders`, with no flag required
- [x] A real run prints `moved N entries from ~/<legacy> to ~/<target>` for a
      folder where top-level entries actually moved, and nothing for a
      folder where none did
- [x] A real run prints a dedicated line when the nested Screenshots folder
      itself is moved (e.g. `moved ~/Pictures/Screenshots to ~/pic/screenshots`)
- [x] Collision detection/reporting and the "leave the legacy folder in
      place when a collision occurred" behavior from 0008 are unchanged
      under the new unconditional default
- [x] `--dry-run` reports the same would-move/would-skip information without
      creating any target directory, moving/removing anything, or invoking
      `xdg-user-dirs-update`
- [x] `dot setup folders --yes` fails with an unknown-option error (argparse
      default), rather than being silently accepted or gated on
- [x] `dot setup folders help` output no longer mentions `--yes` and
      documents `--dry-run` instead
- [x] Idempotency holds: re-running after a clean merge, and re-running
      after a collision was reported, both behave the same as before
- [x] `~/.config/dot/tests/dot.fish` is updated to exercise the above
      (replacing the old `--yes`-gated cases) and
      `fishtape ~/.config/dot/tests/dot.fish` passes

## Implementation Notes

- The `--yes` gate and the `screenshots_emptyish`/`other_entries` machinery
  that computed it were deleted outright rather than special-cased away:
  once merging is unconditional, that machinery had no remaining purpose
  (it existed solely to decide "empty enough to skip the gate").
- `mkdir -p $target_path` and the final `xdg-user-dirs-update` are both now
  guarded by `not set -q _flag_dry_run`, making `--dry-run` a true no-op
  rather than "no-op except for directory scaffolding."
- Collision detection (`test -e $target_path/...`) runs identically in both
  modes; `--dry-run` only gates the actual `mv`/`rmdir`/`mkdir` calls, so the
  reported would-move/would-skip split is exactly what a real run would do.
- Success reporting is per-legacy-folder and suppressed at zero: a folder
  that was already empty (or whose only entries all collided) prints
  nothing, so a routine re-run stays quiet like before.
- All prior collision/idempotency/Screenshots test scenarios were kept,
  just re-pointed at the plain `dot setup folders` invocation instead of
  `--yes`; two scenarios that only differed by which code branch (`--yes`
  vs. silent-empty) they exercised now hit the same branch, but were both
  kept since they still cover distinct fixture shapes (Pictures with vs.
  without unrelated top-level content alongside a colliding Screenshots).
- `fishtape ~/.config/dot/tests/dot.fish` passes (178 tests).
