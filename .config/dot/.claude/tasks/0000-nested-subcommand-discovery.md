---
spec: dot-kde
---

## What to build

Extend the subcommand-discovery mechanism to glob one directory level
deeper, so a `dot` subcommand can live as `commands/<name>/<name>.fish`
alongside a companion file (e.g. a Python helper), not just as a flat
`commands/<name>.fish`. This mechanism exists in two places today
(`dot.fish`'s `__dot_help` and `completions/dot.fish`'s
`__dot_custom_subcommands`), intentionally duplicated rather than shared
(fish autoload constraints) — both must be updated together and stay in
sync. Existing flat-file subcommands must keep working unchanged.

This is pure prefactoring: no KDE-specific behavior is introduced here.

## Acceptance criteria

- [x] `dot help` lists a subcommand that lives at `commands/<name>/<name>.fish`
- [x] `dot <name>` sources and dispatches to `commands/<name>/<name>.fish`'s `_dot_<name>` function
- [x] Tab-completion (`__dot_custom_subcommands`) lists a nested-directory subcommand
- [x] Existing flat-file subcommands (`dot install`) are still discovered and dispatched correctly
- [x] `tests/dot.fish` covers a nested-directory dummy command dispatching correctly, alongside the existing flat-file dispatch case

## Implementation Notes

- The dispatch check in `dot.fish` tries the flat file first, then falls back to `commands/<name>/<name>.fish` — a flat file always wins if both somehow exist for the same name.
- The nested-directory scan requires the file basename to match its containing directory's name (`commands/foo/foo.fish`), not just any `.fish` file one level deep — this matches the acceptance criteria's exact convention and avoids misclassifying a stray companion file (e.g. a `.py` helper) as its own subcommand.
- Tab-completion's nested-directory listing was verified manually (sourcing `completions/dot.fish` and calling `__dot_custom_subcommands` directly) rather than via an automated test — `tests/dot.fish` has no existing infrastructure for testing completions at all, even for pre-existing flat commands, so adding one here would be out of scope for this prefactoring task.
- Updated `CLAUDE.md`'s "Architecture" and "Adding a subcommand" sections to document the new nested-directory convention, since it previously only described the flat-file dispatch contract.
