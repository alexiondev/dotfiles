---
spec: dot-kde
blocked-by: 0001-kde-schema-backed-save
---

## What to build

Implement `dot kde apply` for schema-backed settings: read every entry in
the manifest and write its declared value onto the live system via
`kwriteconfig6`. Re-running it against an already-applied system must be a
no-op with no unintended side effects — this is the idempotence the
feature depends on for safe re-runs after a KDE update or on a freshly
built machine. Add `dot kde apply help`, following the project's
check-for-`help`-before-`argparse` convention.

Add a README row for `dot kde apply`.

## Acceptance criteria

- [x] `dot kde apply` pushes every manifest entry's declared value onto the live system via `kwriteconfig6`
- [x] Re-running `dot kde apply` against a system already matching the manifest changes nothing (idempotent)
- [x] `dot kde apply help` prints usage without writing anything
- [x] Tests run against a scratch `$HOME`, exercising apply over a manifest with schema-backed entries, verifying resulting rc-file contents and idempotence on a second run
- [x] README has a row for `dot kde apply`

## Implementation Notes

- File layout mirrors `save`'s: `write_live_value` (the `kwriteconfig6` counterpart to `read_live_value`) and `apply_one` (mirroring `save_one`'s `parse_identifier` → `resolve_mechanism` → schema-only gate) added to `commands/kde/kde.py`; `cmd_apply` mirrors `cmd_save`'s help/argument/error-handling scaffold. `kde.fish` gained an `apply` dispatch case above `save`.
- `apply` takes no arguments (unlike `save`, which supports an optional identifier) — the task only specifies pushing the whole manifest, and the parent spec's `apply` user story has no per-identifier mode, so `dot kde apply <extra-arg>` is rejected as misuse rather than silently ignored.
- `write_live_value` passes the value positionally after a `--` separator (`kwriteconfig6 --file ... --group ... --key ... -- <value>`) rather than via a `--value` flag, since `kwriteconfig6` takes the value as a mandatory positional argument, not a flag; `--` guards against a value that itself looks like an option.
- Non-schema (shortcuts/freeform) manifest entries are rejected with the same "not yet supported" error `save_one` already raises for those mechanisms, kept out of scope per this task's title ("...apply for schema-backed settings"); those mechanisms are added in later tasks (0004, 0005) without needing to restructure `cmd_apply`.
- `/review-uncommitted` flagged two baseline duplication smells (`apply_one`/`cmd_apply` mirroring `save_one`/`cmd_save`'s shape) and one observation (a failing entry mid-manifest halts `apply` immediately, leaving earlier writes already applied — a partial-apply state, untested either way). Left as-is: the duplication mirrors an already-established local convention from task 0001 rather than introducing a new one, and the partial-apply behavior is consistent with `cmd_save`'s pre-existing control flow, not a new risk introduced by this task.
