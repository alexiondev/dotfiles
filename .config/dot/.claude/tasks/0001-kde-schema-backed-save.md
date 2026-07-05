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

- [ ] `dot kde` and `dot kde save` are discoverable via `dot help` and dispatch correctly
- [ ] Manifest parsing splits correctly on the first `=` (values may contain `=`) and the first two `.`s of the identifier (keys may contain dots/spaces)
- [ ] The `(rcfile → [kcfg files])` mapping table is derived by scanning a schema directory for `<kcfgfile name="...">`, plus the hand-maintained exceptions list for `arg="true">` schemas
- [ ] The schema directory is overridable via an environment variable, defaulting to the real system path
- [ ] `dot kde save <identifier>` reads the current live value via `kreadconfig6` and adds a new declared entry to the manifest
- [ ] `dot kde save` with no arguments refreshes every already-declared manifest entry's stored value from the live system, leaving undeclared settings untouched
- [ ] `dot kde help` and `dot kde save help` print usage without touching the manifest or invoking `kreadconfig6`/`kwriteconfig6`
- [ ] Tests run against a scratch `$HOME` and a fixture `.kcfg` schema directory, exercising manifest read/write, identifier parsing, and mapping-table-driven default lookup, per the project's scratch-`$HOME`-plus-`fishtape` convention
- [ ] README has rows for `dot kde help`, `dot kde save <identifier>`, and `dot kde save`
