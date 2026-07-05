## Problem Statement

Coding agents that need to drive a Gitea-hosted workflow (issues, pull requests, labels) today have two poor options.
The official `tea` CLI is human-oriented: it has no token-efficiency, no contextual guidance, and no agent-facing error conventions.
Gitea's MCP servers expose the full API surface (dozens of tools) rather than being tuned for token or turn efficiency.
There is no Gitea-focused tool built to the same "agent ergonomics" standard that `gh-axi` established for GitHub.

## Solution

Build `gitea-axi`: a thin, generic CLI wrapper around the official `tea` binary that reshapes its output according to the 10 AXI (Agent eXperience Interface) principles — token-efficient output, minimal default schemas, structured errors, contextual next-steps, and so on.
It gives coding agents an ergonomic, low-token way to drive issues and pull requests on any Gitea instance.
It ships both as an installable npm CLI and as an installable Agent Skill, so any agent session can adopt it with one install step.

## User Stories

1. As a coding agent, I want to create a Gitea issue with a title, body, and labels, so that I can record work items for later retrieval.
2. As a coding agent, I want to find issues by label (and other basic filters), so that I can locate relevant work without already knowing its issue number.
3. As a coding agent, I want to read an issue's full body, labels, and comments, so that I can load its context into a session.
4. As a coding agent, I want to add and remove labels on an existing issue, so that I can reflect state transitions as work progresses.
5. As a coding agent, I want to create a pull request from the current branch, so that completed work becomes reviewable.
6. As a coding agent, I want to fetch a pull request's metadata and diff, so that review tooling can operate on it without re-deriving it from git.
7. As a coding agent, I want to post a comment on a pull request, so that findings or notes are visible as a permanent reference on the PR itself.
8. As a coding agent, I want command output in a token-minimized format (TOON, minimal default fields, truncated large fields with an escape hatch), so that repeated calls across a long-running session don't consume excessive context.
9. As a coding agent, I want pre-computed aggregates in list/read output, so that I don't need follow-up calls just to derive obvious derived fields.
10. As a coding agent, I want explicit empty-state output when a query returns nothing, so that "no results" is never ambiguous with an error or a hang.
11. As a coding agent, I want structured errors with actionable suggestions and meaningful exit codes instead of prose failures, so that I can self-correct without the operator's help.
12. As a coding agent, I want mutations to be idempotent and to never prompt interactively, so that unattended, scripted use never stalls or double-applies.
13. As a coding agent, I want contextual next-step suggestions appended after output, so that I know what to call next without being taught the tool from scratch every session.
14. As a coding agent, I want a consistent per-subcommand `--help`, so that I can discover the interface on demand rather than needing it pre-loaded in context.
15. As an operator, I want gitea-axi run with no arguments to show live, actionable repository state instead of a help screen, so that I get immediate value without memorizing flags.
16. As an operator, I want gitea-axi to reuse my existing `tea` login configuration (including multi-instance profiles), so that I don't manage a second set of credentials.
17. As an operator, I want gitea-axi's command surface to stay generic, with no workflow-specific behavior baked in, so that it's useful across different projects and label/workflow conventions without code changes.
18. As an operator, I want gitea-axi published to npm and as an installable Agent Skill, so that I (and others) can adopt it with a single install step.

## Implementation Decisions

- New standalone repository — not bundled into any other tool or CLI framework.
- Developed against the operator's personal Gitea instance; push-mirrored to GitHub for npm publishing and public discoverability/contribution.
- Language/runtime: TypeScript on Node, matching the `gh-axi` reference implementation this design is modeled on.
- Implementation strategy: wrap the `tea` binary as a subprocess, invoking it with `--output json` (or the most structured format it supports) and reshaping that output — not a from-scratch Gitea API client. This reuses `tea`'s auth, multi-instance login, and full command coverage for free.
  - **Flagged risk**: subprocess-wrapping-a-CLI can become fragile or slow at higher call volumes or in edge cases (partial output, non-JSON error text, version drift in `tea`'s own output shape). If this proves to be a real problem in practice, the fallback is a direct Gitea HTTP API client (as Gitea's own MCP server already does) — noted here so it isn't re-litigated from scratch if revisited.
- Auth: no independent credential handling. Every command shells out through `tea`, so it relies entirely on `tea login add` already being configured, including `tea`'s own `--login`/multi-instance profile resolution.
- Command surface: generic Gitea primitives only — issue create/read/find-by-label/update-labels, PR create/get/comment (see User Stories above for the full list). No project-specific or workflow-specific commands (e.g. nothing that hardcodes a particular label taxonomy or state machine).
- Output ergonomics follow the 10 AXI principles (https://axi.md/, https://github.com/kunchenguid/axi), grouped as:
  - Efficiency: TOON-formatted stdout (~40% fewer tokens than JSON), minimal default schemas (3-4 fields per list item), truncated large fields with size hints and an escape hatch to fetch full content.
  - Robustness: pre-computed aggregates to avoid round trips, explicit empty-state messages, structured errors and exit codes, idempotent mutations, no interactive prompts, fail loudly on unknown flags.
  - Discoverability: opt-in session integration plus an on-demand skill, no-args shows live data rather than help text, contextual next-step suggestions appended after output.
  - Help: consistent per-subcommand `--help`.
- Distribution: published to npm as a global-installable CLI, and packaged as an installable Agent Skill (installable the same way as `gh-axi`'s, e.g. via `npx skills`) — both built together from the start, not phased.

## Testing Decisions

- Good tests exercise the actual command-line interface (argv in, stdout/exit-code out) — the one seam every caller depends on — not internal functions, and not a mock of the `tea` subprocess call itself (that would only prove gitea-axi calls `tea` with certain arguments, not that the output is correctly reshaped).
- Tests should run the real, built CLI against either a disposable/fixture Gitea instance or a recorded fixture of `tea`'s own JSON output.
- Prior art: `~/.config/dot/tests/dot.fish` tests `dot`'s subcommands end-to-end with fishtape, building a throwaway bare-git remote fixture per scenario rather than mocking `git`. The equivalent here is a disposable Gitea fixture (or recorded `tea` output) rather than mocking `tea`.

## Out of Scope

- Any workflow-specific commands or hardcoded label/state semantics (tracked separately — see the companion `gitea-axi-integration` spec for one concrete adopter's usage).
- Inline per-line PR review comments (a possible future addition; the primitive here is a plain PR comment).
- A from-scratch Gitea HTTP API client bypassing `tea` (deferred fallback if the subprocess-wrapping approach proves fragile — see flagged risk above).
- Multi-instance orchestration beyond what `tea`'s own login profiles already provide.
- A `dot` (or any other host CLI's) subcommand wrapping this tool — it is intentionally a standalone, independently distributed tool.

## Further Notes

- AXI ("Agent eXperience Interface") is an existing framework: https://axi.md/ and https://github.com/kunchenguid/axi. Its reference implementation, `gh-axi` (https://github.com/kunchenguid/gh-axi), wraps GitHub's `gh` CLI the same way this spec proposes wrapping `tea`, and reports (its own benchmarks) 100% task success vs. 86% for raw `gh`, and 66% cheaper / 74% fewer input tokens / half the interaction turns vs. GitHub's official MCP server on the same 17-task benchmark.
- The official Gitea MCP server (https://gitea.com/gitea/gitea-mcp) was evaluated and rejected as the primary approach: roughly 45 consolidated tools, actively maintained, but — by analogy to the gh-axi-vs-GitHub-MCP benchmark — generic MCP servers expose the full API surface rather than being tuned for token/turn efficiency, and using one directly would forfeit control over output shape.
- Raw `tea` was also evaluated and rejected as the long-term approach (though it remains the dependency this tool wraps): it already supports `--output json/yaml/csv/tsv`, so it's scriptable, but its schemas are human-oriented, not agent-ergonomic (no truncation, no contextual next-steps, no token minimization).
- Name collision check (as of this writing): `gitea-axi` is unclaimed on both npm and GitHub.
