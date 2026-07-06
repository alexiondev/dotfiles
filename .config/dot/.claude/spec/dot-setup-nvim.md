## Problem Statement

On a freshly cloned dotfiles checkout (or any machine where `~/.local/share/nvim/lazy/` is empty or stale), `lazy.nvim` only discovers that plugins are missing when `nvim` is actually launched. The first interactive launch then silently spends a long time cloning `nord.nvim`, `nvim-treesitter`, and `render-markdown.nvim` and compiling every `nvim-treesitter` parser listed in `ensure_installed`, with no obvious progress indication in a normal terminal session — it reads as "nvim isn't starting" rather than "nvim is installing plugins." Nothing in `dot` proactively drives this sync, even though the exact plugin versions are already pinned and tracked in `~/.config/nvim/lazy-lock.json`.

Separately, `nvim-treesitter`'s parser build step has a known race: concurrent parser installs can collide on a relative `tree-sitter-<lang>-tmp` directory, causing one parser (e.g. `bash`) to fail to compile. Because the compiled `.so` never lands in `~/.local/share/nvim/lazy/nvim-treesitter/parser/`, that parser gets retried (and can fail again) on every subsequent `nvim` launch until it eventually succeeds — a silent, recurring cost with no clear signal to the user that anything is wrong.

## Solution

Add an `nvim` task to the `dot setup` family (introduced by the `dot-setup-folders` spec as the general home for idempotent, re-runnable machine-setup tasks). `dot setup nvim` drives a headless `nvim` session that syncs installed plugins to exactly what `lazy-lock.json` already pins, and verifies afterward that every pinned plugin actually landed on disk — turning a silent, ambiguous first-launch stall into an explicit, scriptable, pass/fail setup step. Bare `dot setup` (no task name) runs this alongside `folders` (and any future tasks).

## User Stories

1. As the machine owner, I want `dot setup nvim` to install/sync every plugin pinned in `lazy-lock.json` before I ever open `nvim` interactively, so that my first real editing session isn't interrupted by an unexplained multi-second-to-multi-minute stall that looks like a hang.
2. As the machine owner, I want `dot setup nvim` to use the already-tracked `lazy-lock.json` as the source of truth (not re-resolve latest versions), so that a fresh machine ends up with the exact plugin commits I've already vetted, not whatever is newest upstream that day.
3. As the machine owner, I want `dot setup nvim` to exit non-zero and say clearly which plugin(s) failed to install, so that a partial/broken sync is an obvious, actionable failure rather than something I only notice later inside nvim.
4. As the machine owner, I want re-running `dot setup nvim` when everything is already in sync to be a fast no-op that still exits 0, so that it's safe to include unconditionally in `dot setup`'s bare "run everything" mode without slowing down every re-run.
5. As the machine owner, I want to be able to run `dot setup nvim` in isolation (not just as part of bare `dot setup`), so that I can re-sync plugins on their own after e.g. manually editing `lazy-lock.json` or clearing the plugin directory.
6. As the machine owner, I want `dot setup nvim help` to print usage without touching any plugin state, so that it's consistent with every other `dot` subcommand's `help` behavior.

## Implementation Decisions

- **Subcommand family**: lives under the `dot setup` dispatcher established by the `dot-setup-folders` spec — same nested-subcommand convention (`help`-then-`argparse`, `_dot_setup_nvim_usage`), same dual-mode shape (bare `dot setup` runs every task; `dot setup nvim` runs just this one). This spec does not re-describe the shared dispatcher scaffolding itself; see `dot-setup-folders.md` for that.
- **Core action**: run `nvim --headless "+Lazy! restore" +qa`. `Lazy! restore` checks out every plugin in the spec to the exact commit recorded in `lazy-lock.json` (installing it first via clone if missing), so it both fixes "missing plugin" and "plugin present but on the wrong commit" in one call. No separate `TSUpdate`/`TSInstall` step is needed: because none of the current plugins (`nord.nvim`, `nvim-treesitter`, `render-markdown.nvim`) declare a lazy-loading trigger (`event`/`cmd`/`ft`), they load eagerly as part of this same headless session, which drives `nvim-treesitter`'s own `ensure_installed` parser-compilation step as a natural side effect — matching what was observed when reproducing the issue.
- **Failure detection**: `nvim`'s process exit code from `--headless ... +qa` does not reliably reflect whether `Lazy! restore` itself succeeded (Lazy reports failures via its own UI/messages, not necessarily the process exit status). `dot setup nvim` must independently verify success after the headless run completes, by checking that every plugin name declared in `lazy-lock.json` has a corresponding directory under `~/.local/share/nvim/lazy/`. Any pinned plugin missing a directory is treated as a failure: print which plugin(s) didn't install and exit non-zero.
- **Parser-compile failures are out of scope for pass/fail**: the `tree-sitter-<lang>-tmp` collision race affects `nvim-treesitter`'s internal parser build, not the plugin-directory check above (nvim-treesitter's own directory will exist regardless of whether an individual parser compiled). `dot setup nvim`'s success criterion is "all pinned plugins are present," not "all treesitter parsers compiled" — a parser-level compile flake is expected to self-heal on a later `nvim` launch or `:TSUpdate`, per the `Further Notes` in this spec's investigation. Detecting and retrying individual parser build failures is not attempted here.
- **No package-list file**: unlike `dot install`, there's nothing to record — `lazy-lock.json` is already the tracked source of truth, so `dot setup nvim` never writes to it.

## Testing Decisions

- **Guiding principle**: test `dot setup nvim`'s own logic (that it invokes `nvim` correctly, that it correctly detects success vs. a missing plugin) through the real CLI entry point, faking only the external `nvim` binary — not real plugin installs, real git clones, or real compilation, which would be slow and network-dependent in tests.
- **Primary seam**: full CLI invocation of `dot setup nvim` (and bare `dot setup`), run against a scratch `$HOME` per test case — the existing project convention (see `dot install`'s and the planned `dot setup folders`' tests). No new seam is introduced.
- **Faking `nvim`**: a `PATH`-prepended fake `nvim` binary, mirroring the fake-`pacman`/fake-`sudo`/fake-`xdg-user-dirs-update` technique already used/planned in `tests/dot.fish`. The fake logs its invocation args (so a test can assert `dot setup nvim` called it with `--headless "+Lazy! restore" +qa`) and, driven by an env var or scratch-`$HOME` fixture, can simulate "all plugins present" vs. "one plugin missing" by controlling whether it creates the expected directories under the scratch `~/.local/share/nvim/lazy/`.
- **Cases to cover**: a successful sync (fake `nvim` creates all pinned plugin directories) exits 0; a plugin missing after the fake run exits non-zero and names the missing plugin; re-running against an already-fully-synced scratch `$HOME` is still a pass (idempotency) without requiring the fake to do anything different; bare `dot setup` runs the `nvim` task alongside `folders`; `dot setup nvim help` prints usage and never invokes the fake `nvim` at all.
- **Prior art**: `tests/dot.fish`'s scratch-`$HOME`-plus-`fishtape` pattern, and specifically the fake-binary-via-`PATH` technique used for `dot install` (and planned for `dot setup folders`'s `xdg-user-dirs-update` fake).

## Out of Scope

- The `dot setup` dispatcher scaffolding itself (bare-runs-everything, per-task dispatch, `_dot_setup_usage`) — already specified in `dot-setup-folders.md`; this spec only adds the `nvim` task onto it.
- The `folders` and any future (e.g. `groups`) `dot setup` tasks — unaffected by this spec beyond now running alongside `nvim` in bare `dot setup`.
- Fixing the underlying `nvim-treesitter` `tree-sitter-<lang>-tmp` race itself (an upstream plugin behavior) — `dot setup nvim` tolerates it rather than working around it.
- Any change to `~/.config/nvim`'s plugin specs, `lazy-lock.json` contents, or which plugins/parsers are installed — this spec only adds a way to proactively sync to what's already pinned.
- A `~/.github/README.md` command-table row — not written here, but required by the project's standard "adding a subcommand" checklist at implementation time.

## Further Notes

- This spec grew out of debugging a real "nvim isn't starting" report: the actual cause was an empty `lazy.nvim` plugin directory triggering a full, slow reinstall on first launch, compounded by a `tree-sitter-bash-tmp` mkdir collision that made the `bash` parser fail and re-attempt on every subsequent launch until it happened to succeed. `dot setup nvim` addresses the first (silent first-launch stall) directly; the second (parser race) is a pre-existing upstream flake this spec does not attempt to fix.
