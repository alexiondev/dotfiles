---
blocked-by: [0005-kde-shortcuts-mechanism, 0009-kde-shortcut-completion]
---

## What to build

`dot kde diff`'s broad-scan (the pass that reports *undeclared* drift, not
just already-declared entries) currently only walks schema-backed
identifiers via `iter_schema_identifiers`. Shortcuts are treated the same
as freeform in `cmd_diff` -- checked only when already present in the
manifest -- per the code comment at the top of that loop. That comment is
overstated for shortcuts: unlike freeform, which genuinely has no
enumeration source, shortcuts *are* enumerable via `kglobalaccel`'s
`allMainComponents`/`allActionsForComponent`, and `iter_shortcut_identifiers`
(added in 0009 for tab-completion) already walks exactly that.

Add a second broad-scan pass in `cmd_diff`, after the existing schema-backed
one, over `sorted(set(iter_shortcut_identifiers()))`: for each identifier,
compare `shortcutKeys` against `defaultShortcutKeys` (the same live/default
read already used for declared shortcuts), and tag `declared`/`undeclared`
exactly like the schema loop. Remove the shortcuts branch from the
manifest-only loop below it (now redundant), leaving that loop for freeform
only, since freeform is the only mechanism that still can't be enumerated.

Tolerate two failure modes without aborting the whole command:
- The enumeration call itself (`allMainComponents`) failing (no live
  session, no `busctl`) -- print one diagnostic to stderr and skip the
  shortcuts block entirely, same as any other reported problem in `diff`.
- An individual action failing to resolve (`_resolve_shortcut_action_id`
  raising because its owning app hasn't registered with kglobalaccel this
  session) -- print that one identifier's error to stderr and continue,
  matching the schema loop's existing per-identifier tolerance.

Update `DIFF_USAGE` to reflect that shortcuts now participate in broad-scan
alongside schema-backed settings, leaving only freeform as declared-only.

## Acceptance criteria

- [x] `dot kde diff` reports undeclared shortcut drift (a shortcut changed
      from its packaged default but never `dot kde save`d) without requiring
      it to be in the manifest first
- [x] Already-declared shortcut drift is still reported, tagged `declared`,
      with no duplicate line from the old manifest-only loop
- [x] A shortcut belonging to an app that hasn't registered with kglobalaccel
      this session produces one stderr diagnostic for that identifier and
      does not stop the rest of the scan (schema block, other shortcuts,
      freeform block) from completing
- [x] If the `allMainComponents` enumeration itself fails (no `busctl`, no
      live session), `diff` prints one diagnostic, skips the shortcuts block,
      and still completes the schema and freeform passes, exiting 0
- [x] Freeform remains declared-only (unchanged) -- only its loop comment and
      the removed shortcuts branch change
- [x] `DIFF_USAGE` text updated to describe shortcuts as broad-scanned
- [x] Verified manually against the real session (consistent with the
      shortcuts mechanism's existing test carve-out, 0005/0009) -- no new
      automated tests
- [x] Full existing test suite still passes unchanged

## Implementation Notes

- `cmd_diff` (`commands/kde/kde.py`) gained a second broad-scan pass between
  the existing schema-backed loop and the manifest-only loop: it walks
  `sorted(set(iter_shortcut_identifiers()))` (the same enumeration
  `cmd_complete` already uses), compares `shortcutKeys` against
  `defaultShortcutKeys` per identifier, and tags `declared`/`undeclared`
  exactly like the schema loop.
- The manifest-only loop below it lost its `shortcuts` branch entirely
  (`resolve_mechanism` returning `"shortcuts"` now just falls through
  `if mechanism != "freeform": continue`), since the new broad-scan pass
  already reports every declared shortcut mismatch -- keeping the old branch
  would have double-printed them.
- Two failure modes, handled at different granularity: `iter_shortcut_identifiers()`
  itself is wrapped in `try/except (RuntimeError, OSError)` -- a failure there
  (no live session, missing `busctl`) prints one diagnostic and skips the
  whole shortcuts block, letting the schema and freeform passes still run.
  Inside the per-identifier loop, `read_shortcut_value` raising `RuntimeError`
  (an app that hasn't registered with kglobalaccel this session yet) prints
  one diagnostic for that identifier and continues, matching the schema
  loop's existing per-identifier tolerance.
- Real-world validation on this machine: manually ran the same enumeration in
  a throwaway script before implementing, confirming 29 of 278 registered
  shortcuts differed from default (the Meta+1-9 desktop-switch remap,
  Meta+Shift+1-9 window-to-desktop binds, and Meta+A/Meta+Shift+A activity
  switching) -- all 29 were `dot kde save`d into the manifest in the same
  session as a prerequisite for testing this cleanly. After implementing,
  `dot kde diff` reported all 30 shortcuts (29 plus the pre-existing
  `ksmserver.Lock Session`) as `declared` with correct default values, and
  ~34 unrelated `RuntimeError`s for apps not launched this session (Konsole,
  Spectacle, Dolphin, etc.) printed to stderr without aborting the scan.
  Removing one entry (`kwin.Switch to Desktop 1`) from the manifest and
  re-running confirmed it flips to `undeclared` with the same live/default
  values, then restoring the manifest flipped it back to `declared` --
  confirms both tags work and the manifest was left untouched by `diff`
  itself (read-only, as documented).
- Full test suite re-run after the change: 101/101 pass, unchanged from
  before this task. No automated tests added for the new pass itself, per
  the shortcuts mechanism's existing carve-out (0005's Implementation Notes:
  a live `kglobalaccel` D-Bus session isn't practically substitutable without
  disproportionate mock infrastructure) -- the existing tests already
  exercise `dot kde diff` against the real live session and continued to
  pass with the new pass active, incidentally covering that it doesn't break
  anything even though it isn't asserting on the new pass's own output.
