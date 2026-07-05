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

- [ ] `dot help` lists a subcommand that lives at `commands/<name>/<name>.fish`
- [ ] `dot <name>` sources and dispatches to `commands/<name>/<name>.fish`'s `_dot_<name>` function
- [ ] Tab-completion (`__dot_custom_subcommands`) lists a nested-directory subcommand
- [ ] Existing flat-file subcommands (`dot install`) are still discovered and dispatched correctly
- [ ] `tests/dot.fish` covers a nested-directory dummy command dispatching correctly, alongside the existing flat-file dispatch case
