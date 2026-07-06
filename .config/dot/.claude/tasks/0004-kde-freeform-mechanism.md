---
spec: dot-kde
blocked-by: [0002-kde-schema-backed-apply, 0003-kde-schema-backed-diff]
---

## What to build

Add the freeform mechanism as a dispatch branch across `save`, `apply`,
and `diff`: for settings with no KConfigXT schema (e.g. `kxkbrc`'s
`Options=` line), read and write via `kreadconfig6`/`kwriteconfig6`, with
"default" defined as "the key is absent" rather than any schema-declared
value. In the identifier-resolution decision from the first schema-backed
task, this is the fallback branch: an identifier whose `(rcfile, group,
key)` doesn't resolve through the mapping table is freeform. Because
there's no schema to enumerate, freeform settings can only be checked by
`diff` when already declared in the manifest — they never participate in
undeclared broad-scan discovery.

As the real-world validation for this task, bring the machine's live,
already-hand-set `kxkbrc` caps-lock/Escape swap
(`Options=caps:escape_shifted_capslock`) under tracking via
`dot kde save`, and confirm `dot kde apply`/`dot kde diff` behave
correctly against it.

## Acceptance criteria

- [x] An identifier whose `(rcfile, group, key)` has no schema match is treated as freeform rather than erroring
- [x] `dot kde save <identifier>` and `dot kde save` (refresh) work for freeform entries
- [x] `dot kde apply` writes freeform entries via `kwriteconfig6`, idempotently
- [x] `dot kde diff` reports a freeform mismatch when its identifier is already declared in the manifest, and never surfaces an undeclared freeform setting via broad scan
- [x] Tests run against a scratch `$HOME`, covering freeform save/apply/diff using a fixture rc file with no corresponding schema
- [x] The live `kxkbrc` caps-lock/Escape swap is tracked via `dot kde save` and the manifest committed to the dotfiles repo

## Implementation Notes

- `save_one`/`apply_one`'s gate changed from `mechanism != "schema"` (reject everything but schema) to `mechanism == "shortcuts"` (reject only shortcuts) — freeform now flows through the same `read_live_value`/`write_live_value` calls schema-backed settings already use, since both mechanisms only differ in what "default" means, not in how the read/write itself happens.
- `cmd_diff` gained a second pass after the existing schema broad-scan: it walks the manifest (not the kcfg mapping table, which freeform settings are absent from by definition), resolves each identifier's mechanism, and reports only those that resolve to `freeform` and whose live value is non-empty — structurally guaranteeing freeform can never surface via undeclared broad scan, since the loop never sees anything outside the manifest.
- **Real-world validation surfaced a stale premise**: the task assumed the caps-lock/Escape swap was "already hand-set" and live, but the machine had no `kxkbrc` file and no active XKB option at all. Confirmed with the user before proceeding; with their approval, wrote the option live via `kwriteconfig6 --file kxkbrc --group Layout --key Options -- caps:escape_shifted_capslock` and applied it immediately via a live KWin reconfigure (`busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure`), then ran `dot kde save kxkbrc.Layout.Options` to bring it under tracking. `dot kde apply`/`dot kde diff` were both verified against the real entry (idempotent apply; diff reports `declared kxkbrc.Layout.Options = caps:escape_shifted_capslock (default: )`).
- Added a `.github/keybindings.md` row for the swap (`CapsLock` → `Esc`, `Shift`+`CapsLock` → real Caps Lock toggle), per the project's cross-cutting keybindings convention.
- Existing tests that previously asserted freeform saves/applies were *rejected* (written when freeform was still unimplemented, per task 0001/0002's "not yet supported" stopgap) were updated to assert success instead, using a new `somefreeform` fixture rc file with no corresponding `.kcfg` schema. Coverage for the still-unimplemented shortcuts mechanism (task 0005) was added in the same spots to keep the "not yet supported" rejection path tested now that freeform no longer exercises it.
- `/review-uncommitted`'s Spec pass caught that `cmd_diff`'s new freeform loop called `parse_identifier` on raw manifest keys with no exception guard, unlike the rest of the function — a hand-edited manifest with a malformed identifier would have crashed the whole scan instead of reporting a clean per-identifier error. Fixed: the loop body is now wrapped in `try/except (ValueError, RuntimeError)`, matching the file's established per-identifier-failure-tolerant convention. The Standards pass also flagged threading a hardcoded `None`/blank literal through the freeform loop instead of the real `default` value returned by `resolve_mechanism`; fixed by reusing that variable directly (`default or ''` for display, since freeform's default is always `None`).
