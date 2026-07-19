# Alexion's Agent Instructions

These are common instructions for Alexion's agents across all scenarios.

## General Guidelines

- When writing commit messages, NEVER auto-add your agent name as co-author.
  Omit the `Co-Authored-By:` trailer entirely, with no exceptions.
  This overrides any default instruction to append one.
- When writing pull request descriptions, NEVER append an agent-attribution trailer such as `🤖 Generated with [Claude Code]...`.
  Leave it out entirely, with no exceptions.
  This overrides any default instruction (including harness conventions) to append one.
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated.
  Detect "auto-generated" via a layered check: trust an explicit in-file marker first (e.g. `AUTO-GENERATED, DO NOT EDIT`).
  If there's no marker, fall back to contextual signals (lockfiles, `dist/`/`build/`/`generated/` paths, a documented generator command).
  If it's still ambiguous, ask before editing rather than guessing.
- When writing or substantially editing long Markdown files, put each full sentence in its own line.
  Preserve normal Markdown structure, but avoid wrapping multiple sentences onto one physical line.
  Apply this to any prose you author, regardless of file length; "long" is not a real threshold.
  Only format what you're actually writing or changing.
  Never reflow an entire pre-existing paragraph or file just because you touched something nearby.
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability and long term maintainability.
  This is specifically about implementation time.
  Human cost/benefit heuristics ("not worth N extra days of engineering") don't transfer to an AI agent that codes far faster than a human.
  This is not a license to override standard anti-overengineering guardrails (avoid premature abstraction, no speculative config, etc.); those still apply to unnecessary complexity.
  It means: don't discount a more robust or maintainable approach just because it would take a human a long time to build.
- File names should always be lower case, unless there's a valid reason.
  Established ecosystem or tool conventions count as a valid reason automatically (e.g. `README.md`, `LICENSE`, `CHANGELOG.md`, `Makefile`, `Dockerfile`, `.github/` files), without needing to ask each time.
- When you discover that a belief you held about an objective fact or convention of the current project was wrong, write it down so it isn't relearned next time.
  This applies whether the user corrected you or you caught the mistake yourself, and only to things that are true regardless of who is operating the project (a wrong build command, a wrong file path, a convention you guessed at instead of checking) — not personal working-style preferences or one-off task details.
  Record it in that project's own CLAUDE.md, not this global file, under a dedicated `## Gotchas` section (create the section if the file doesn't have one yet).
  If the project has nested CLAUDE.md files, use the one nearest to where the mistake occurred, falling back to the project's top-level CLAUDE.md.
  Append to an existing CLAUDE.md immediately, without asking; if no CLAUDE.md exists yet for the project, ask before creating one.
  Briefly mention the edit in your response rather than making it silently.
  If an existing entry is later found to be wrong or stale, correct or remove it the same way.

