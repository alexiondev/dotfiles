## Problem Statement

I run Claude Code as my coding agent on `neogaia`, wired deeply into this flake: skills, a sudo-guard hook, shared agent instructions, and the whole `.claude/` workflow.
Pi is a young, fast-moving, self-modifying terminal coding agent that I want to evaluate as an alternative harness.
I need to install it on the laptop in a way that lets me try it honestly — same model, same account — without unpicking any of the Claude Code setup and without committing myself to Pi before it has earned a permanent place.

The evaluation only means something if the one variable under test is the harness itself, and if backing Pi out later is trivial.

## Solution

Add a new `pi` Module that installs Pi for the primary user on `neogaia`, enabled by the Enable convention like every other feature.
It flips the home-manager `programs.pi-coding-agent` module on and freezes exactly one file — `settings.json` — pinning the provider and model so Pi runs the same brain as Claude Code (Anthropic, Opus) and disabling analytics so Pi never attempts a runtime write to that frozen file.

Everything else is left to Pi's own writable state directory (`~/.pi/agent/`): no agent context, no skills, no extensions, no keybindings, no custom model providers.
Pi authenticates by reusing my existing Claude subscription, and that credential is deliberately left unmanaged by the flake so no secret touches the repo and re-auth survives rebuilds — exactly as the `claude-code` Module already treats its login.

The result is a minimal, non-disruptive, side-by-side experiment: Claude Code stays the daily driver, Pi sits alongside it, and removing Pi is a one-line `enable` flip.

## User Stories

1. As the operator, I want Pi installed as its own auto-discovered Module that stays inert until a Host enables it, so that Pi reads as one more `enable = true` line on `neogaia` and never rides silently onto future Hosts.
2. As the operator, I want Pi enabled only on `neogaia`, so that the experiment is contained to the machine I actually drive.
3. As the operator, I want Pi to run Anthropic's Opus by default, matching Claude Code's model, so that any difference I observe between the two is attributable to the harness and not the model.
4. As the operator, I want Pi's provider and default model pinned reproducibly in the flake, so that the same Pi configuration would rebuild identically on any Host.
5. As the operator, I want Pi's analytics disabled in that same pinned configuration, so that Pi never attempts the one runtime write it would otherwise make to the frozen settings file.
6. As the operator, I want Pi to authenticate by reusing my existing Claude subscription rather than a separate API key, so that the comparison hits the same account at zero marginal cost.
7. As the operator, I want Pi's credential left unmanaged by the flake, so that no secret is committed to a public repo and my authentication survives rebuilds.
8. As the operator, I want Pi installed with no agent context, no skills, and no extensions, so that I see Pi's native behaviour rather than a port of the Claude Code setup.
9. As the operator, I want Pi to keep full ownership of its writable state directory, so that its self-modifying behaviour — generated extensions, skills, prompt templates, installed packages, sessions — works unimpeded.
10. As the operator, I want Pi sourced from the base package set and bumped with the normal flake update, so that it stays reasonably fresh without a second package set evaluated for one tool.
11. As the operator, I want the Module laid out as a directory rather than a single file, so that promoting Pi later — adding rendered skills or extensions — is an additive change rather than a restructure.
12. As the operator, I want backing Pi out to be a single `enable` flip, so that an experiment that does not pan out leaves no residue.

## Implementation Decisions

**pi Module**
- A new Module under its own directory, following the shape of the existing `claude-code` Module, declaring a single `enable` option under the `modules` tree and guarding its body with the Enable convention.
- The directory layout (rather than a single file) is chosen so that later rendering of a skills or extensions source is an additive edit, not a move.
- On enable, the Module turns on the home-manager `programs.pi-coding-agent` module for the primary user. That upstream module ships the `pi-coding-agent` package (base package set) and manages the state directory's declared files.
- The Module freezes exactly one file through that upstream module's `settings` option: the default provider set to Anthropic, the default model set to Opus (the exact model-id string confirmed against Pi's own model catalogue at build time), and analytics disabled.
- No other upstream option is set: `context`, `models`, `keybindings`, `extraPackages`, and `configDir` are all left at their defaults, so home-manager renders nothing but `settings.json` into `~/.pi/agent/` and Pi owns every other path there.
- Rationale for the single frozen file: among the files the upstream module can render, `settings.json` is the only one Pi writes at runtime, and only its analytics keys — disabling analytics removes even that, so freezing it is safe and never fights Pi's self-modification, which targets other paths entirely.
- Credentials are out of the flake by design. Pi reuses the Claude subscription via its own login, and the resulting token lives under Pi's state directory, which home-manager does not overwrite — mirroring the `claude-code` Module's treatment of its login.
- Security posture is inherited, not added: the `claude-code` Module already widens the sudo credential cache system-wide for the primary user, so Pi's `bash` tool can spend a warm credential. Pi does not pass through Claude Code's cold-cache sudo guard, and no equivalent guard is added for Pi in this deliverable. This is an accepted, bounded posture for a supervised single-user experiment.

**neogaia Host**
- The `neogaia` Host enables the new Module with a single `enable = true`, alongside its existing feature list.
- No other Host is touched; the desktop and servers do not yet exist in the flake and would each opt in on their own terms.

## Testing Decisions

- A good test here asserts externally-observable evaluation and build success of the whole `neogaia` Host, not the internals of the Module. Installing a Module is config authoring, and the meaningful unit is the Host it composes into.
- **Primary seam (required, reused):** the `neogaia` Host evaluates and its system toplevel builds via `nix flake check` (the `checks.x86_64-linux.neogaia` target). Building the toplevel drives the Auto-loader discovering the new Module, the `programs.pi-coding-agent` home-manager integration resolving, the frozen `settings.json` rendering, and every enabled Module's config merging without conflict.
- No new seam is introduced. This is the single high seam that `laptop-mvi.md` established and that every Module in this repo is verified through; an install-a-Module feature does not justify a second one.
- No unit-level test of the Module in isolation. The config-merge model makes the whole-Host build the highest and most meaningful seam.
- Prior art: the existing `claude-code`, `gitea-axi`, `fish`, `tmux`, and `nvim` Modules are all verified this way — enabled on `neogaia`, exercised by the toplevel build.
- The genuine end-to-end confirmation — launching `pi`, authenticating against the Claude subscription, and running the agent — is a manual post-build action on the real machine and is not automated, consistent with how interactive login is handled for Claude Code.

## Out of Scope

- Any harvest/promote pipeline for sharing Pi's self-modifications across machines — rendering a repo-held skills or extensions source into Pi's state directory. Deferred until Pi earns a permanent slot.
- A shared skill source between Pi and Claude Code for a fairer comparison, exploiting their common `SKILL.md` skill format.
- A Pi-specific sudo guard (or any tool-permission guard) built as a Pi extension.
- An `AGENTS.md` context carrying the operator's cross-agent house rules (commit conventions, no attribution trailer, markdown and filename rules). Its absence means Pi's commits will not automatically follow those conventions during the experiment; this is accepted.
- Custom model providers (`models.json`), custom keybindings, and any non-Anthropic provider.
- Moving Pi to the `unstable` overlay for head-of-channel freshness.
- Wiring the credential through a secret store; sops is not yet wired on this Host, and Pi follows the same unmanaged-credential path as Claude Code until it is.
- Enabling Pi on any Host other than `neogaia`.
- An ADR recording the "promote agent self-modifications into the flake rather than sync mutable agent state" stance. It is not enacted by this deliverable; if Pi is promoted and the harvest pipeline is built, that becomes a real, repo-wide decision — covering Claude Code too — worth recording then.

## Further Notes

- **Why the single frozen file matters:** Pi's real self-modification surface (generated extensions, skills, prompt templates, installed package code, sessions, trust decisions) lives in paths under `~/.pi/agent/` that the upstream home-manager module never manages, regardless of what the Module declares. Freezing `settings.json` therefore constrains none of it, and disabling analytics removes the only runtime write that file would otherwise receive.
- **Promotion path is left open by construction:** the directory-shaped Module and the untouched `configDir` mean that, if Pi sticks, a repo-held skills or extensions source can be rendered into the state directory with a writable-directory / read-only-leaf layout — the same mechanism this repo already uses for Claude Code skills — without restructuring anything decided here.
- **Fair-comparison intent:** matching the model (Opus) and the account (the Claude subscription) is deliberate, so the experiment isolates the harness. Choosing a lighter model or a separate key would introduce a second variable and blur the read.
- **Reversibility:** because only `settings.json` is frozen and the credential and all self-modification state live outside the flake, disabling the Module removes Pi cleanly, leaving Pi's own state directory as the only residue on disk.
