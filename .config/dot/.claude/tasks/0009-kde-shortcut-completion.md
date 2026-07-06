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

- [x] `python3 kde.py complete` includes every currently-registered `kglobalshortcutsrc.<componentUnique>.<actionUnique>` identifier, sourced live via `allMainComponents`/`allActionsForComponent`
- [x] Schema-backed identifiers print first, followed by shortcut identifiers, as two distinct blocks — not interleaved into one merged sorted list
- [x] Shortcut identifiers print plain, with no friendly-name description text
- [x] If the D-Bus walk raises `RuntimeError` or `OSError`, the shortcuts block is omitted, the schema block still prints normally, and nothing is written to stderr
- [x] Freeform identifiers remain unlisted by `cmd_complete` (unchanged, confirmed not a regression)
- [x] Verified manually against a live session — no new automated tests, consistent with the existing shortcuts-mechanism test carve-out (spec's testing decisions, 0005's Implementation Notes)

## Implementation Notes

- `iter_shortcut_identifiers` (new, `commands/kde/kde.py`) walks `allMainComponents()` then `allActionsForComponent()` per component, yielding `kglobalshortcutsrc.<componentUnique>.<actionUnique>`. `cmd_complete` wraps that walk in `sorted(set(...))` and appends it as a second print loop after the existing schema-backed one, inside a `try/except (RuntimeError, OSError)` that falls back to an empty list on any failure — so a missing `busctl` or an unreachable D-Bus session degrades completion instead of breaking it.
- Manually verified both paths: live run on this machine prints 278 shortcut identifiers after 322 schema-backed ones; with `busctl` removed from `PATH` (simulating a non-KDE/minimal shell), `cmd_complete` still exits 0, prints only the 322 schema identifiers, and writes nothing to stderr.
- `/review-uncommitted`'s Standards pass flagged two judgement-call smells: (1) the D-Bus call/unpack idiom for `allActionsForComponent` was duplicated between the new function and `_resolve_shortcut_action_id`; (2) the silent `except` swallow had no comment explaining why. Fixed both: extracted a shared `_actions_for_component(component_unique)` helper used by both call sites, and added a comment on the `try` explaining that fish invokes this on every TAB press in shells that may lack a live KDE session, so a broken shortcuts source must never cost the already-printed schema candidates. Re-ran the full test suite (101/101 pass) and both manual checks after the fix.
- No automated tests added, per the task's own acceptance criterion and the shortcuts mechanism's existing test carve-out (0005's Implementation Notes: a live D-Bus session isn't practically substitutable without disproportionate mock infrastructure).
