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

- [ ] `dot kde apply` pushes every manifest entry's declared value onto the live system via `kwriteconfig6`
- [ ] Re-running `dot kde apply` against a system already matching the manifest changes nothing (idempotent)
- [ ] `dot kde apply help` prints usage without writing anything
- [ ] Tests run against a scratch `$HOME`, exercising apply over a manifest with schema-backed entries, verifying resulting rc-file contents and idempotence on a second run
- [ ] README has a row for `dot kde apply`
