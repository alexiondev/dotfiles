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

- [ ] `dot kde diff` reports every schema-backed setting whose live value differs from its schema-declared default
- [ ] Each reported mismatch is tagged declared or undeclared based on manifest presence
- [ ] `dot kde diff` makes no writes under any circumstances
- [ ] `dot kde diff help` prints usage without scanning
- [ ] Tests run against a scratch `$HOME` and fixture `.kcfg` schema directory, covering: a declared mismatch, an undeclared mismatch, and a setting matching its default (not reported)
- [ ] README has a row for `dot kde diff`
