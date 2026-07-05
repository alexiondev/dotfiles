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

- [ ] A filename collision between a legacy folder and its already-populated
      short-named target is skipped, not overwritten (the target's existing
      file is preserved byte-for-byte)
- [ ] The skipped collision is reported to the user
- [ ] The legacy folder is left in place (not removed) when a collision
      occurred, even though `--yes` was given and other non-colliding files
      in it were moved
- [ ] Re-running `dot setup folders` after a collision was reported and left
      in place behaves consistently (doesn't lose the previously-skipped
      file, doesn't re-move already-migrated files)
- [ ] `~/.config/dot/tests/dot.fish` covers the above cases and
      `fishtape ~/.config/dot/tests/dot.fish` passes
