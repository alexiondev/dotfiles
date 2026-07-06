---
spec: dot-setup-folders
blocked-by: 0006-setup-dispatcher-and-folders-core
---

## What to build

Extend `dot setup folders`'s migration so a legacy folder found non-empty
(any entry at all, including a stray dotfile or KDE metadata like a
`.directory` file, counts as non-empty) stops and prints what would be moved,
then refuses to proceed unless an explicit `--yes` flag was passed on the
command line — no interactive prompt. With `--yes`, the migration proceeds
for that folder the same way the empty-folder path already does.

This applies uniformly across all 8 mapped categories, including the nested
`Pictures/Screenshots→pic/screenshots` rename from the prior slice: a
non-empty `Screenshots` folder is also gated behind the same confirmation
rule.

## Acceptance criteria

- [x] A legacy folder with real content (a real file, not just an empty
      directory) refuses to migrate without `--yes`, prints what would have
      been moved, and leaves the folder and its contents untouched
- [x] The same legacy folder migrates successfully when `--yes` is passed
- [x] A legacy folder containing only a stray dotfile/metadata file (e.g. a
      fake `.directory`) is still treated as non-empty and triggers the same
      confirmation gate
- [x] `~/.config/dot/tests/dot.fish` covers the above cases and
      `fishtape ~/.config/dot/tests/dot.fish` passes

## Implementation Notes

- `--yes`'s actual move reuses the exact same branch shape as the existing
  silent-empty path (rename `Screenshots` → `screenshots` when present, then
  `rmdir` the legacy folder), extended to also `mv` any remaining top-level
  entries into the target first. Screenshots is always moved as one atomic
  unit — its individual files are never mv'd/reported separately — so a
  non-empty `Screenshots` (own acceptance criterion in the parent spec) is
  gated and migrated the same way a non-empty top-level file would be.
- Collision handling (no-clobber `mv -n`, reporting skipped files, leaving the
  legacy folder in place on a collision) is explicitly out of scope here —
  it's owned by 0008-folders-collision-handling.md, per that task's own
  frontmatter/spec section. The `--yes` path added here uses a plain `mv`.
- `/review-uncommitted` flagged two minor issues, both fixed: a stale comment
  claiming a helper variable was used by both the silent-empty and `--yes`
  paths when it was only read by the latter, and a duplicated `find`
  invocation computing the same top-level listing twice under one condition
  (now computed once and reused). It also flagged the non-empty "would move"
  preview listing recursively-nested files individually instead of treating
  `Screenshots` as one unit like the real move does — fixed so the preview
  and the actual move share the same top-level-entries list.
