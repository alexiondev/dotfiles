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

- [ ] An identifier whose `(rcfile, group, key)` has no schema match is treated as freeform rather than erroring
- [ ] `dot kde save <identifier>` and `dot kde save` (refresh) work for freeform entries
- [ ] `dot kde apply` writes freeform entries via `kwriteconfig6`, idempotently
- [ ] `dot kde diff` reports a freeform mismatch when its identifier is already declared in the manifest, and never surfaces an undeclared freeform setting via broad scan
- [ ] Tests run against a scratch `$HOME`, covering freeform save/apply/diff using a fixture rc file with no corresponding schema
- [ ] The live `kxkbrc` caps-lock/Escape swap is tracked via `dot kde save` and the manifest committed to the dotfiles repo
