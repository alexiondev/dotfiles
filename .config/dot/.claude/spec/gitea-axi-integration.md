## Problem Statement

Today, `to-spec`, `to-tasks`, and `implement` track specs and tasks as local files (`.claude/spec/<slug>.md`, `.claude/tasks/<NNNN>-<slug>.md`) scoped to a single git working tree.
That means task state and context don't survive across the machine boundary — a spec or task can't be picked up from a different clone, referenced from a PR, or handed to a differently-scoped agent session without manually carrying the files over.
There's also no natural place for `review-uncommitted`'s findings to live once produced, other than the terminal output, which the operator has to capture manually if they want it preserved as a record.

## Solution

Once `gitea-axi` (see the companion `gitea-axi` spec) exists, replace the local-file storage in this project's skill-based task-management pipeline with Gitea issues and pull requests: specs and tasks become labeled issues, "readiness" becomes a label state, and implemented work becomes a pull request that `review-uncommitted` comments on directly.
The workflow-specific semantics (label names, state transitions, PR-to-issue linking) live entirely in the skills' own prose, calling `gitea-axi`'s generic primitives — `gitea-axi` itself stays unaware of this project's conventions.

## User Stories

1. As the operator, I want `to-spec` to open a Gitea issue containing the spec instead of writing a local file, so that the spec is visible and referenceable outside my local working tree.
2. As the operator, I want the spec issue labeled to mark it ready for task breakdown, so that a later session can find it without me telling it the issue number.
3. As the operator, I want a new session to be able to locate and read a spec issue by its readiness label, so that I can hand off spec-to-task work across sessions without manually passing context.
4. As the operator, I want `to-tasks` to open one Gitea issue per task instead of writing local task files, so that each task is independently discoverable and referenceable the same way the spec is.
5. As the operator, I want each task issue to retain a reference back to its parent spec issue, so that the `spec` traceability that today's local task-file frontmatter provides isn't lost in the move to issues.
6. As the operator, I want `to-tasks` to remove the spec issue's readiness label once tasks are created from it, so that the state machine reflects "spec has already been broken down" and isn't reprocessed.
7. As the operator, I want to ask a new session to implement "the next task" and have it find the right task issue by its readiness label, so that I don't have to look up and paste an issue number myself.
8. As the operator, I want `implement` to read a task issue's full details before starting work, so that it has the same context a local task file would have given it.
9. As the operator, I want `implement` to open a pull request (carrying the implementation commit) once work is done, instead of leaving only an uncommitted or committed local diff, so that the work is reviewable and mergeable through Gitea like any other PR.
10. As the operator, I want `review-uncommitted` to fetch its diff and spec context from the pull request and its linked issue when run in this workflow, so that I don't need a local spec file for it to work against.
11. As the operator, I want `review-uncommitted`'s three-axis findings posted as a comment on the pull request, so that they're visible as a permanent record on the PR itself, not just in my terminal.
12. As the operator, I want the label taxonomy and state machine (spec/task readiness, PR-to-issue linking conventions) to be easy to change later, so that I can iterate on the workflow without touching `gitea-axi`'s code.
13. As the operator, I want PR granularity (one commit vs. several, one task vs. several per PR) decided case-by-case between me and the agent at `implement` time, rather than fixed by a rule baked into the skill.

## Implementation Decisions

- Depends on `gitea-axi` existing first (see the companion spec) — this spec only covers how this project's skills consume it, not the tool itself.
- Affected skills: `to-spec`, `to-tasks`, `implement`, `review-uncommitted`. Each swaps its local-file I/O (`Read`/`Write`/`Edit` against `.claude/spec/` and `.claude/tasks/`) for calls to `gitea-axi`'s generic issue/PR primitives.
- `to-spec` opens an issue (instead of writing `.claude/spec/<feature-slug>.md`) carrying the same spec content and format, labeled to mark it as newly created and ready for breakdown.
- `to-tasks` reads the spec issue, opens one issue per task slice (instead of `.claude/tasks/<NNNN>-<slice-slug>.md`), each carrying a reference back to the parent spec issue (replacing the current `spec` frontmatter field), labels each task issue as ready for implementation, and removes the readiness label from the spec issue once done.
- `implement` locates its target task issue (by number if given, or by readiness label/query if asked for "the next task"), reads it in place of a local task file, does the work, and opens a pull request carrying the implementation commit — in place of just staging locally and leaving the commit to the operator.
- `review-uncommitted` gains a Gitea-aware path: when working against a PR, it fetches PR diff/metadata and the linked spec/task issue instead of `git diff HEAD` and a local spec file, and posts its aggregated Risk/Standards/Spec report as a single PR comment once done (per the companion spec's decision to keep this a single comment, not per-finding inline comments).
- Label taxonomy and exact naming (today referred to provisionally as "spec"/"ready-for-agent") are explicitly left open — to be finalized when these skill updates are actually implemented, not fixed by this spec.
- PR granularity (commits per PR, tasks per PR) is explicitly left as a case-by-case decision made between the operator and the agent at `implement` time — not a fixed rule this spec encodes.

## Testing Decisions

- Skills are prose (`SKILL.md` files), not unit-testable code — there is no automated test seam for the skill updates themselves. Verification is behavioral: running each updated skill against a real (or disposable) Gitea instance end-to-end and confirming the resulting issues, PRs, labels, and comments match what the prose describes.
- The one seam that is testable in the traditional sense is `gitea-axi` itself, already covered by the companion spec — these skill updates are downstream consumers of that seam, not a new one.
- No prior art in this repo for testing prompt-based skills; `~/.config/dot/tests/dot.fish` (fishtape, end-to-end against fixtures) is the closest pattern, but it tests code, not prose, so it doesn't transfer directly.

## Out of Scope

- Building `gitea-axi` itself (fully covered by the companion `gitea-axi` spec).
- Deciding the actual label taxonomy and state machine names — deferred to implementation time.
- Deciding PR granularity rules — deferred to case-by-case decisions at `implement` time.
- Inline per-finding PR review comments for `review-uncommitted` (deferred enhancement, noted in the companion spec).
- Any change to `codebase-design`, `domain-modeling`, `test-driven-development`, or other skills not in the four listed above.

## Further Notes

- This spec assumes `gitea-axi`'s generic primitives (issue create/read/find-by-label/update-labels, PR create/get/comment) are sufficient for the four listed skills. If implementation reveals a missing primitive, it should be added to `gitea-axi` itself (kept generic) rather than special-cased here.
- This is an opinionated, single-adopter view of `gitea-axi` — it intentionally isn't part of the `gitea-axi` spec itself, since that tool is meant to stay usable by others regardless of this project's specific workflow conventions.
