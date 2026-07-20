## What to build

A git `Module`, following the `Enable convention` and configured natively through home-manager, that carries the operator's commit identity — enabled on `neogaia`.

Today that identity exists only in one repository's local configuration on one machine. It is therefore invisible to every other checkout, absent from any future `Host`, and lost on a reimage. Declaring it makes committing work anywhere, reproducibly, like everything else in the flake.

The identity matches the one already present throughout this repository's history, so existing commits and future ones agree. Committing it is not a disclosure: it appears in every commit this repository has ever published.

It is a `Module` rather than base plumbing because a `Host` that should not carry a personal commit identity is easy to imagine once the servers exist.

## Acceptance criteria

- [x] A git `Module` following the `Enable convention` exists and is enabled on `neogaia`
- [x] The commit identity is configured through home-manager and matches the one used in existing history
- [x] `nix flake check` builds the `neogaia` toplevel
- [x] Manual confirmation: committing in a repository outside this checkout succeeds with no per-command identity override
- [x] The stale note in the project's agent instructions claiming git identity is unconfigured is corrected, since commits already work here through repository-local configuration

## Implementation Notes

`programs.git.userName`/`userEmail` are renamed in this home-manager pin and emit an obsolete-option trace.
The module uses `settings.user.name`/`settings.user.email`.
Do not "fix" it back.

Review on the pull request asked for the module on every host, which was first built by defaulting `enable` to true and dropping the per-host line.
The operator then chose the opposite: `enable` defaults to false and each host enables it explicitly, so a host keeps reading as a full checklist of what it carries rather than hiding a default-on module.
Enabling it is therefore a step when adding a host.

The commit name is the literal `"alexion"` rather than `config.user.name`, which review raised as duplication.
A Unix login and a commit display name are separate concepts that merely coincide here, so binding them would let a host overriding its login silently rewrite the operator's commit identity.

The manual confirmation was met against the built configuration, not the running machine: `nixos-rebuild switch` needs sudo and has not run, so `~/.config/git/config` does not yet exist on `neogaia`.
The generated gitconfig was built from the `neogaia` toplevel and a commit driven under `env -i` with a scratch `HOME`, producing `alexion <contact@alexion.dev>` with no per-command override.
This proves the derivation rather than the deployment, and the live check remains owed at the next rebuild.

Review surfaced an unanticipated hazard that proved harmless.
Home-manager writes `~/.config/git/config`, while an undeclared `~/.gitconfig` also exists and outranks it per key.
It holds only a `tea` credential helper and no `user.*`, so it does not shadow the identity, confirmed by re-running the commit test with both files present.
Declaring that credential helper is a reasonable follow-up, since it will not survive a reimage.
