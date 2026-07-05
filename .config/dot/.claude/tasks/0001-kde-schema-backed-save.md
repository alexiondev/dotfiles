---
spec: dot-kde
blocked-by: 0000-nested-subcommand-discovery
---

## What to build

Stand up `dot kde` itself: the fish dispatcher plus its Python helper,
living together under `commands/kde/` per the nested-subcommand layout
from the prior task. Establish the manifest file (flat text file directly
under `~/.config/dot/`, one `identifier=value` line each, split on the
first `=` only; identifier split on the first two `.`s into
`file.group.key`, leaving the key free to contain further dots or spaces).

Implement the KConfigXT schema-backed mechanism: reads and writes go
through `kreadconfig6`/`kwriteconfig6`, and the "default" value for a
setting comes from its `.kcfg` schema. Build the `(rcfile → [kcfg files])`
mapping table by scanning the system's KConfigXT schema directory for
files that statically declare their target rc file
(`<kcfgfile name="...">`), plus a small hand-maintained list for the
exceptions that only declare their target file at runtime
(`<kcfgfile arg="true">` — `kwin.kcfg` is a known example). The schema
directory location must be overridable (e.g. via an environment variable),
defaulting to the real system path, so tests can point it at a fixture
directory of synthetic `.kcfg` files instead.

Structure identifier resolution as a dispatchable decision (rc file is
`kglobalshortcutsrc` → shortcuts; else resolves via the mapping table →
schema-backed; else → freeform) even though only the schema-backed branch
is implemented yet — later tasks add the other two branches without
restructuring this.

Implement `dot kde save` for schema-backed settings, in both modes:
run with no arguments, refresh every already-declared manifest entry's
value from the live system; run with an explicit identifier, read its
current live value and add it to the manifest as a new declared entry.
Add `dot kde help` and `dot kde save help`, following the project's
check-for-`help`-before-`argparse` convention at each dispatch level.

Add README rows for `dot kde help`, `dot kde save <identifier>`, and
`dot kde save` (no arguments).

## Acceptance criteria

- [x] `dot kde` and `dot kde save` are discoverable via `dot help` and dispatch correctly
- [x] Manifest parsing splits correctly on the first `=` (values may contain `=`) and the first two `.`s of the identifier (keys may contain dots/spaces)
- [x] The `(rcfile → [kcfg files])` mapping table is derived by scanning a schema directory for `<kcfgfile name="...">`, plus the hand-maintained exceptions list for `arg="true">` schemas
- [x] The schema directory is overridable via an environment variable, defaulting to the real system path
- [x] `dot kde save <identifier>` reads the current live value via `kreadconfig6` and adds a new declared entry to the manifest
- [x] `dot kde save` with no arguments refreshes every already-declared manifest entry's stored value from the live system, leaving undeclared settings untouched
- [x] `dot kde help` and `dot kde save help` print usage without touching the manifest or invoking `kreadconfig6`/`kwriteconfig6`
- [x] Tests run against a scratch `$HOME` and a fixture `.kcfg` schema directory, exercising manifest read/write, identifier parsing, and mapping-table-driven default lookup, per the project's scratch-`$HOME`-plus-`fishtape` convention
- [x] README has rows for `dot kde help`, `dot kde save <identifier>`, and `dot kde save`

## Implementation Notes

- File layout: `commands/kde/kde.fish` (thin dispatcher: help-before-dispatch at the `dot kde` level, then hands off to the Python helper) plus `commands/kde/kde.py` (manifest parsing, mapping-table derivation, mechanism resolution, `kreadconfig6` invocation, and `save`'s own help-before-work check).
- Manifest location: `~/.config/dot/kde-manifest`, a flat file directly under `~/.config/dot/` as specified.
- Mechanism dispatch (`resolve_mechanism`) implements all three branches described in the parent spec (shortcuts / schema / freeform) even though only `schema` is wired to real behavior; `shortcuts` and `freeform` both currently raise a clear "not yet supported" error from `save_one`, so later tasks can fill them in without restructuring the dispatch.
- Test fixtures added under `tests/fixtures/kcfg/`: `testrc.kcfg` (a plain `<kcfgfile name="...">` schema, including an entry whose ini `key=` differs from its schema `name=`, and one entry whose key contains dots and spaces), `kwin.kcfg` (an `arg="true"` schema resolved only via the hand-maintained exceptions list), and `unmapped.kcfg` (an `arg="true"` schema absent from that list, proving it's never guessed at from its own filename).
- Per the project's testing convention, `kreadconfig6` is never mocked for the tests exercising actual `save` behavior — it runs for real against fixture rc files under a scratch `$HOME`. It's faked (via a `$PATH`-prepended logging stub) only for the two tests asserting that `dot kde help` / `dot kde save help` never invoke it.
- Applied two small cleanups surfaced by `/review-uncommitted`'s Standards pass before closing out: extracted a shared `_parse_kcfg` helper (was duplicated between `build_kcfg_map` and `find_schema_default`), and introduced a `Setting = namedtuple("Setting", ["file", "group", "key"])` to stop threading those three strings as separate parameters across `resolve_mechanism`/`find_schema_default`/`read_live_value`/`save_one`.
- The Spec pass caught that the `unmapped.kcfg` fixture was created but never actually exercised by a test; added a case asserting `dot kde save unmapped.Whatever.Setting` resolves to freeform rather than schema-backed.
