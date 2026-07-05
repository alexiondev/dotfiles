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

- [ ] A legacy folder with real content (a real file, not just an empty
      directory) refuses to migrate without `--yes`, prints what would have
      been moved, and leaves the folder and its contents untouched
- [ ] The same legacy folder migrates successfully when `--yes` is passed
- [ ] A legacy folder containing only a stray dotfile/metadata file (e.g. a
      fake `.directory`) is still treated as non-empty and triggers the same
      confirmation gate
- [ ] `~/.config/dot/tests/dot.fish` covers the above cases and
      `fishtape ~/.config/dot/tests/dot.fish` passes
