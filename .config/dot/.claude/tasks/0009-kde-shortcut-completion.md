---
blocked-by: 0005-kde-shortcuts-mechanism
---

## What to build

`dot kde save`'s tab-completion (`cmd_complete` in `commands/kde/kde.py`)
currently only enumerates schema-backed identifiers via
`iter_schema_identifiers` — it was built as a side effect of the `diff`
task (0003) and never revisited when the shortcuts mechanism (0005)
landed. Extend `cmd_complete` to also enumerate shortcut identifiers.

Source the shortcut identifiers live via `kglobalaccel`, mirroring how
schema identifiers are freshly parsed from `.kcfg` files on every call:
call `allMainComponents()` to get every registered component's
`componentUnique`, then `allActionsForComponent()` per component
(already used by `_resolve_shortcut_action_id`) to get every
`actionUnique`, yielding `kglobalshortcutsrc.<componentUnique>.<actionUnique>`
candidates. No caching — walk fresh on every invocation.

Print shortcut identifiers as their own block, after the existing
schema-backed block — not merged into one interleaved sorted list.
Keep them plain, with no friendly-name description text, matching the
existing schema-identifier output style.

If the D-Bus walk fails for any reason — a non-zero `busctl` exit
(`RuntimeError`, already raised by `_kglobalaccel_call`) or `busctl`
itself being missing (`OSError` from `subprocess.run`) — swallow it
silently: omit the shortcuts block, still print the schema block, and
emit no stderr diagnostic.

Freeform identifiers (e.g. `kxkbrc.Layout.Options`) are explicitly out
of scope for this task: there is no schema to enumerate them from, so
this stays a permanent, accepted completion gap, not something to fix
here.

## Acceptance criteria

- [ ] `python3 kde.py complete` includes every currently-registered `kglobalshortcutsrc.<componentUnique>.<actionUnique>` identifier, sourced live via `allMainComponents`/`allActionsForComponent`
- [ ] Schema-backed identifiers print first, followed by shortcut identifiers, as two distinct blocks — not interleaved into one merged sorted list
- [ ] Shortcut identifiers print plain, with no friendly-name description text
- [ ] If the D-Bus walk raises `RuntimeError` or `OSError`, the shortcuts block is omitted, the schema block still prints normally, and nothing is written to stderr
- [ ] Freeform identifiers remain unlisted by `cmd_complete` (unchanged, confirmed not a regression)
- [ ] Verified manually against a live session — no new automated tests, consistent with the existing shortcuts-mechanism test carve-out (spec's testing decisions, 0005's Implementation Notes)
