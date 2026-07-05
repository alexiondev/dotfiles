## Problem Statement

The old `~/wrk/dotfiles` repo's `setup_folders` (part of its bash `bin/dot init`) renamed the standard XDG user folders to short names (`Documents→doc`, `Downloads→dwn`, etc.) for better fish shell-completion ergonomics — shorter shared prefixes are easier to disambiguate by typing fewer characters. That behavior has no equivalent in the new bare-repo `dot` CLI. Right now this machine's `user-dirs.dirs` is untracked and has drifted from even the old convention: it uses the full XDG default names, plus an ad hoc `XDG_PROJECTS_DIR=$HOME/Projects` line that never existed in the old repo at all. If this machine were rebuilt today, none of the short-name convention would be restored, and the current drifted state isn't recorded anywhere.

## Solution

Add a `folders` task to a new `dot setup` subcommand family (the general home for idempotent, re-runnable machine-setup tasks, as opposed to `dot init`'s one-shot bootstrap). `dot setup folders` brings the 8 standard XDG user directories under the project's short-name convention, tracks the resulting `user-dirs.dirs` directly as a plain dotfile, and safely migrates any content sitting in the old, full-named folders into their short-named replacements.

`~/wrk` (already in active use, e.g. `~/wrk/dotfiles`) replaces the old `Projects`-style folder as the general working-files location, but is treated as a plain convention-only directory, not a tracked XDG category.

## User Stories

1. As the machine owner, I want the standard XDG user folders renamed to short names (`doc`, `dwn`, `mus`, `pic`, `vid`, `.desktop`), so that fish-completion on my home directory has shorter, easier-to-disambiguate shared prefixes than the full XDG default names.
2. As the machine owner, I want `Templates` and `Public` (both unused) collapsed into a single hidden `.ignoreme` folder, so that apps respecting `XDG_TEMPLATES_DIR`/`XDG_PUBLICSHARE_DIR` don't scatter files directly into `$HOME`, without needing two separate unused folders.
3. As the machine owner, I want the nested `Pictures/Screenshots` folder lowercased to `pic/screenshots` in the same pass as the `Pictures→pic` rename, so that the screenshot folder matches the rest of the short-folder naming convention without a separate migration step.
4. As the machine owner, I want `~/wrk` to have no XDG variable pointing at it, so that a non-standard, barely-recognized XDG extension (`XDG_PROJECTS_DIR`) doesn't get tracked for a directory that already works fine as a plain convention.
5. As the machine owner, I want `user-dirs.dirs` tracked directly in the bare dotfiles repo like any other plain dotfile, so that the desired short names are recorded and restorable on a fresh machine without needing a code-generation step.
6. As the machine owner, I want `dot setup folders` to migrate content out of any legacy full-named folder into its short-named replacement automatically when the legacy folder is empty, so that re-running setup on a fresh install requires no manual folder shuffling.
7. As the machine owner, I want `dot setup folders` to stop and ask for explicit confirmation before moving anything out of a legacy folder that actually has content in it, so that I never silently lose files to an automated migration I forgot was going to run.
8. As the machine owner, I want confirmation to be satisfiable via a `--yes` flag rather than an interactive prompt, so that the same command works identically whether I'm running it by hand or from an automated/tested context.
9. As the machine owner, I want a filename collision between a legacy folder and an already-populated short-named target to never be silently overwritten, so that re-running the migration after a partial/interrupted prior run can't destroy a file just because both sides happen to have a same-named entry.
10. As the machine owner, I want to be told which files were skipped due to a collision and have the legacy folder left in place when that happens, so that I have a clear, actionable signal that something needs manual attention instead of silent partial data loss.
11. As the machine owner, I want `dot setup folders` to notify running apps of the directory changes via `xdg-user-dirs-update` after migrating, so that session-long apps pick up the new paths without requiring a full logout/login.
12. As the machine owner, I want to run `dot setup` with no arguments to perform every machine-setup task (folders plus future ones like extra groups) in one command, so that setting up a fresh machine doesn't require remembering and running each task individually.
13. As the machine owner, I want to also be able to run `dot setup folders` on its own, so that I can re-run just this one task in isolation (e.g. after a confirmation was declined) without re-running unrelated setup tasks.

## Implementation Decisions

- **Subcommand family**: `dot setup`, following the project's existing nested-subcommand dispatch convention (`help`-then-`argparse`, `_dot_<name>_usage`). Bare `dot setup` (no arguments) runs every machine-setup task unconditionally (folders, plus future tasks such as extra groups, mirroring the old bash `bin/dot init`'s dual-mode: no-args ran everything, an explicit keyword ran just one task). `dot setup folders` runs just the folders task.
- **Folder mapping** (identical to the old repo's `setup_folders`, no changes): `Desktop→.desktop`, `Documents→doc`, `Downloads→dwn`, `Music→mus`, `Pictures→pic`, `Videos→vid`, `Templates→.ignoreme`, `Public→.ignoreme`. `Templates` and `Public` both point at the *same* `.ignoreme` folder, as before.
- **Nested screenshots rename**: as part of the same `Pictures→pic` migration pass, the nested `Screenshots` folder (currently created empty by KDE/Spectacle defaults) is renamed to lowercase `screenshots`, so the result is `pic/screenshots`. This is folded into the folders task rather than deferred to the separate Spectacle-keybind work, since it's the same naming-convention concern and falls out for free once `Pictures/*` is moved into `pic/`.
- **`wrk` is out of the XDG mapping**: no `XDG_PROJECTS_DIR` (or any other XDG variable) is written for it. It's a plain, convention-only directory. The currently-existing ad hoc `~/Projects` folder (created by this machine's diverged, untracked `user-dirs.dirs`) is left alone — out of scope for the folders task, since it was never one of the 8 standard XDG categories the task manages, and it's empty and harmless.
- **`user-dirs.dirs` is tracked directly** as a plain dotfile in the bare repo (not generated/overwritten by `dot setup folders` from a hardcoded table each run) — unlike KDE's rc files (tracked via a separate declarative-manifest mechanism, see the `dot-kde` spec), `user-dirs.dirs` has no volatile/machine-specific fields, so it fits the same direct-tracking treatment as any other plain dotfile (`.bashrc`, etc.). The tracked file is the single source of truth for the desired short names.
- **`dot setup folders` still needs a small hardcoded table** mapping each of the 8 standard XDG categories to its legacy default folder name (`Documents`, `Downloads`, etc.) — this is used purely to locate content left behind by a fresh XDG-defaults install and merge it into the already-tracked short-named target; it is not the source of truth for the target names themselves (that's the tracked `user-dirs.dirs`).
- **Migration safety, per legacy folder**:
  - Empty (strict check: any file at all, including dotfiles/metadata like a stray KDE `.directory` file, counts as non-empty) → merge silently, no prompt.
  - Non-empty → print what would be moved and require an explicit `--yes` flag before proceeding. No interactive prompt.
  - Collisions (a same-named entry exists in both the legacy folder and its short-named target) → use no-clobber semantics (e.g. `mv -n`) so a colliding file is never silently overwritten; report which files were skipped; leave the legacy folder in place (don't remove it) if any collision occurred, rather than deleting a folder that still holds something that couldn't be merged.
- **Post-migration step**: run `xdg-user-dirs-update` (no arguments) once folder moves are complete, to notify running apps/portals via its D-Bus signal. This is safe against the hand-tracked file — `user-dirs.dirs`'s own header documents that local edits are preserved across runs of the tool.

## Testing Decisions

- **Guiding principle**: test the folders task's own logic (mapping, empty-vs-non-empty gating, `--yes` behavior, collision handling, idempotency) through the real CLI entry point, not the internals of `mv`/`mkdir` themselves.
- **Primary seam**: full CLI invocation of `dot setup folders` (and bare `dot setup`), run against a scratch `$HOME` per test case — the existing project convention (see `dot install`'s tests). No new seam is introduced.
- **External command handling**: `xdg-user-dirs-update` is faked out via a `PATH`-prepended fake binary that logs its invocation (and exit code), exactly mirroring how `sudo`/`pacman` are faked for `dot install`'s tests. Real `mkdir`/`mv`/`rmdir` run for real against the scratch `$HOME` — no need to fake filesystem operations themselves.
- **Cases to cover**: fresh migration of empty legacy folders (no `--yes` needed); a legacy folder with real content refuses without `--yes` and proceeds with it; the nested `Pictures/Screenshots→pic/screenshots` rename; a stray dotfile (e.g. a fake `.directory`) in an otherwise-"empty" legacy folder still triggers the confirmation gate; a filename collision between legacy and target is skipped (not overwritten), reported, and leaves the legacy folder in place; re-running `dot setup folders` after a clean migration is a no-op (idempotency); bare `dot setup` runs the folders task as part of running everything; `dot setup folders help` prints usage and touches nothing.
- **Prior art**: `tests/dot.fish`'s existing scratch-`$HOME`-plus-`fishtape` pattern, and specifically the fake-`sudo`/fake-`pacman`-via-`PATH` technique used for `dot install`.

## Out of Scope

- The **extra groups** task (`dot setup groups` or similar, porting the old `.extra_groups`/`setup_users` behavior) — it will share the same `dot setup` dispatcher and dual-mode (bare-runs-everything vs. named-task) shape decided here, but its own design (group list format, idempotency, etc.) was not addressed in this spec.
- Any KDE-side settings (caps-lock/Escape swap, screenshot keybinds, Lock Session rebind) — covered separately by the `dot-kde` spec/design.
- Removing the currently-existing, now-orphaned `~/Projects` folder — explicitly left alone, not cleaned up by this feature.
- Any `~/.github/README.md` command-table row or `~/.github/keybindings.md` update — not applicable here (no keybind changes), but the README row is still required by the project's standard "adding a subcommand" checklist at implementation time.

## Further Notes

- The old bash `setup_folders`'s naive `mv $from/* $to` has a latent bug this design deliberately avoids: an unquoted glob against an empty directory can misbehave, and it has no collision protection at all. The no-clobber-plus-report behavior specified here is a deliberate improvement over the old script's behavior, not a straight port.
- This spec covers only the `folders` task; `dot setup` itself (the dispatcher, `_dot_setup_usage`, wiring into `commands/`, the completions/help-glob duplication point noted in the project's `CLAUDE.md`) needs to exist as scaffolding for this task to attach to, even though its only other planned task (extra groups) is out of scope here.
