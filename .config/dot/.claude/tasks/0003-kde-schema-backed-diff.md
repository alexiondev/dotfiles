---
spec: dot-kde
blocked-by: 0001-kde-schema-backed-save
---

## What to build

Implement `dot kde diff`'s broad, read-only scan for schema-backed
settings: walk every `(rcfile, group, key)` reachable through the
mapping table built in the prior task, compare each live value
(`kreadconfig6`) against its schema-declared default, and report every
mismatch. Each reported mismatch is tagged as declared (its identifier is
present in the manifest — an intentional, already-tracked deviation) or
undeclared (never explicitly declared). `diff` never writes anything.
Add `dot kde diff help`, following the project's
check-for-`help`-before-`argparse` convention.

Add a README row for `dot kde diff`.

## Acceptance criteria

- [x] `dot kde diff` reports every schema-backed setting whose live value differs from its schema-declared default
- [x] Each reported mismatch is tagged declared or undeclared based on manifest presence
- [x] `dot kde diff` makes no writes under any circumstances
- [x] `dot kde diff help` prints usage without scanning
- [x] Tests run against a scratch `$HOME` and fixture `.kcfg` schema directory, covering: a declared mismatch, an undeclared mismatch, and a setting matching its default (not reported)
- [x] README has a row for `dot kde diff`

## Implementation Notes

- `cmd_diff` (in `commands/kde/kde.py`) reuses `build_kcfg_map`/`iter_schema_identifiers` (already built for `kde.py complete`) to walk every schema-backed `(rcfile, group, key)`, then `find_schema_default`/`read_live_value` (already built for `save`) to compare live vs. default. No new scanning machinery was needed — this task's whole job was wiring existing pieces together into a read-only report.
- Output format: one line per mismatch, `<declared|undeclared> <identifier> = <live> (default: <default>)`. Not specified by the task, so chosen to read clearly and stay unambiguous under substring matching in tests (avoided bracketed tags like `[declared]`, since fish's `string match` glob treats `[...]` as a character class).
- `/review-uncommitted`'s Spec pass caught that `cmd_diff` had no error handling around `read_live_value`, unlike `cmd_apply`/`cmd_save`'s `try/except (ValueError, RuntimeError)` — a single `kreadconfig6` failure would have aborted the entire broad scan with an uncaught traceback, contradicting `diff`'s "report every mismatch" framing. Fixed: `cmd_diff` now catches `RuntimeError` per-identifier, prints a warning to stderr, and continues scanning the rest.
- The Standards pass flagged the "build map → iterate `sorted(set(iter_schema_identifiers(...)))`" shape as now duplicated between `cmd_diff` and `cmd_complete`, and the new test scenarios' fixture boilerplate as repeating the `apply` tests' shape almost verbatim. Left both as-is: the loop duplication is two call sites doing genuinely different things with the result, and the test boilerplate matches this file's already-established per-scenario convention (each scenario resets `$HOME` independently) rather than introducing a new pattern.
- Post-closeout fix (user-reported): `~/.config/fish/completions/dot.fish`'s `dot kde` completion block only ever listed `save`/`help` as verbs — `apply` was never added when task 0002 built it, and this task initially repeated the same omission for `diff`. Fixed both by adding `apply` and `diff` to the top-level verb-offering line and to the post-subcommand `help` gating; verified manually via `complete -C"dot kde "` and `complete -C"dot kde apply "`/`complete -C"dot kde diff "`.
