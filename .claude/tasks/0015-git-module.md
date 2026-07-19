## What to build

A git `Module`, following the `Enable convention` and configured natively through home-manager, that carries the operator's commit identity — enabled on `neogaia`.

Today that identity exists only in one repository's local configuration on one machine. It is therefore invisible to every other checkout, absent from any future `Host`, and lost on a reimage. Declaring it makes committing work anywhere, reproducibly, like everything else in the flake.

The identity matches the one already present throughout this repository's history, so existing commits and future ones agree. Committing it is not a disclosure: it appears in every commit this repository has ever published.

It is a `Module` rather than base plumbing because a `Host` that should not carry a personal commit identity is easy to imagine once the servers exist.

## Acceptance criteria

- [ ] A git `Module` following the `Enable convention` exists and is enabled on `neogaia`
- [ ] The commit identity is configured through home-manager and matches the one used in existing history
- [ ] `nix flake check` builds the `neogaia` toplevel
- [ ] Manual confirmation: committing in a repository outside this checkout succeeds with no per-command identity override
- [ ] The stale note in the project's agent instructions claiming git identity is unconfigured is corrected, since commits already work here through repository-local configuration
