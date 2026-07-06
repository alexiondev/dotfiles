---
spec: dot-setup-folders
blocked-by: 0007-folders-non-empty-confirmation
---

## What to build

Make the `--yes`-confirmed merge from the prior slice collision-safe: when a
legacy folder and its short-named target both contain an entry with the same
name, use no-clobber move semantics so the target's existing file is never
silently overwritten. Report which files were skipped due to a collision, and
leave the legacy folder in place (don't remove it) whenever any collision
occurred during that folder's migration, rather than deleting a folder that
still holds something that couldn't be merged.

This closes the gap left by the old bash `setup_folders`'s naive `mv $from/*
$to`, which had no collision protection at all.

## Acceptance criteria

- [x] A filename collision between a legacy folder and its already-populated
      short-named target is skipped, not overwritten (the target's existing
      file is preserved byte-for-byte)
- [x] The skipped collision is reported to the user
- [x] The legacy folder is left in place (not removed) when a collision
      occurred, even though `--yes` was given and other non-colliding files
      in it were moved
- [x] Re-running `dot setup folders` after a collision was reported and left
      in place behaves consistently (doesn't lose the previously-skipped
      file, doesn't re-move already-migrated files)
- [x] `~/.config/dot/tests/dot.fish` covers the above cases and
      `fishtape ~/.config/dot/tests/dot.fish` passes

## Implementation Notes

- The two prior branches (silent-empty merge vs. `--yes`-confirmed merge)
  were unified into one `if test (count $other_entries) -eq 0; or set -q
  _flag_yes` branch, since the collision-detection/no-clobber logic is
  identical either way. This has one side effect beyond the letter of the
  acceptance criteria (which frame collision handling around the `--yes`
  path): a legacy folder that's otherwise "empty" except for an emptyish
  nested `Screenshots` dir now also gets collision-checked against an
  already-populated `pic/screenshots` on the silent, no-`--yes` path. This
  closes the same unguarded-`mv` gap the spec calls out as the motivating
  problem (the old code's silent-path `mv $screenshots_path
  $target_path/screenshots` had no collision protection at all either), so
  it was kept rather than special-cased away. Covered by its own test
  ("a silent-path Screenshots collision ...").
- Collision detection is a pre-check (`test -e $target_path/...`) before an
  actual `mv -n`, rather than relying on `mv -n`'s exit code alone, so each
  colliding entry can be individually identified and reported by path.
- `/review-uncommitted` (risk: Medium, standards: 0 hard violations, spec:
  0 missing/wrong requirements) raised no changes needed; the one scope note
  it flagged (the silent-path Screenshots case above) was a deliberate,
  judged-correct decision rather than an oversight.
