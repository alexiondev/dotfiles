---
name: dotfiles
description: Conventions for this machine's dotfiles bare-repo setup. Use when editing any file under $HOME managed by this repo, or when extending the dot CLI (subcommands, completions, bootstrap, tests).
---

# Dotfiles

This machine's dotfiles are a bare git repo at `~/.dotfiles`, checked out with
`$HOME` as its work-tree. The `dot` fish function wraps that invocation
(`git --git-dir=~/.dotfiles --work-tree=$HOME $argv`, declared with
`--wraps=git`), so every git subcommand works through it: `dot status`,
`dot add`, `dot commit`, `dot push`, etc.

## Always add by explicit path

`status.showUntrackedFiles=no` is set locally, and `.gitignore` only excludes
`.dotfiles` itself plus OS/editor cruft — it is **not** a whitelist. That
means virtually everything under `$HOME` reads as untracked, and `git status`
deliberately hides all of it.

**Always run `dot add <specific-path>`.** Never `dot add -A`, `dot add .`, or
any wildcard add — that would try to stage the entire home directory (caches,
secrets, everything).

See [DOT-CLI.md](DOT-CLI.md) for the `dot` command's own architecture,
bootstrap logic, subcommand dispatch, and test suite.
