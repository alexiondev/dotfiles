---
name: implement
description: Implement a task file produced by /to-tasks on its own branch, review it, close it out, and open a PR.
disable-model-invocation: true
---

Implement a task file end-to-end: branch, build it, review it, close it out, and open a PR.

## Process

### 1. Read the task file and check blockers

The user passes the path to a task file (`.claude/tasks/<NNNN>-slug.md`, as produced by `/to-tasks`) explicitly — don't infer one from context.

If the task's frontmatter has a `blocked-by` field, read each referenced task file and check for any unresolved `- [ ]` acceptance criterion. If any blocker isn't fully resolved, warn the user which one and why, and confirm before proceeding — don't refuse outright.

### 2. Sync `main` and branch off it

Switch to `main`, fast-forward it (`git pull --ff-only`), then create and switch to a branch named `task-<NNNN>-<slug>` — taken verbatim from the task file's basename, so `.claude/tasks/0003-issue-view-and-truncation.md` gives `task-0003-issue-view-and-truncation`.
Use whatever git invocation the project itself uses; a repo may wrap it.

Stop and ask the user before going further if:

- **The working tree has uncommitted changes.** Never stash them automatically.
- **`git pull --ff-only` fails.** Local `main` has diverged; report what diverged. Never `reset --hard`.
- **The task's `blocked-by` work isn't reachable from `main`.** The blocker's PR is likely unmerged; name it.

If the task branch already exists, switch to it and carry on — don't recreate it, and don't rebase it onto the freshly pulled `main`.
Always branch off `main`, never off a sibling task branch.

### 3. Implement

Build the work described in the task's "What to build" section, satisfying its acceptance criteria. ALWAYS use `/test-driven-development`, at the seams already agreed when the spec or task was written.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

### 4. Stage the changes

Stage (`git add`) each file you create or modify, specifically — not `git add -A` — so nothing untracked and unrelated gets swept in.

### 5. Review

Run `/review-uncommitted`, passing the task file itself as the spec source — it already links back to its parent spec via its `spec` frontmatter field, if any. Address anything it raises before moving on.

Keep its report — step 7 puts part of it in the PR.

### 6. Close out the task file

Mark every acceptance criterion `[x]` if satisfied or `[-]` if deliberately dropped, so none are left `[ ]`. Append a `## Implementation Notes` section explaining any deviations from the plan — dropped criteria (referencing which, and why), scope changes, decisions made mid-implementation, follow-ups worth flagging. Skip the section only if nothing deviated. Leave the `spec` and `blocked-by` frontmatter fields untouched — they're a permanent record, not a checklist to clear (see `to-tasks`'s `TASK-FORMAT.md`).

Stage the updated task file with the rest.

### 7. Commit, push, and open a PR

Make **one** commit for the whole task, code and task file together.
Match the repo's existing commit convention — read its recent history or its CLAUDE.md, don't assume one — and reference the task in the subject, e.g. `(task 0003)`.

Push the branch (`git push -u origin task-<NNNN>-<slug>`) and open a pull request against `main` with the repo's forge CLI: `tea` for Gitea, `gh` for GitHub.
Never base the PR on a sibling task branch.
Open it ready, not draft.

The PR body carries:

- The task file's path.
- A short summary of what was built, and any deviations — the same ones just written into `## Implementation Notes`.
- A `## Review` section: the `## Risk` block from step 5 verbatim (overall rating plus its six factor lines), then **only** the Standards and Spec findings left unaddressed, each with a one-line reason. Findings that were fixed are already in the diff; leave them out.

Don't ask for confirmation before pushing or opening the PR.
If the repo has no remote, stop after the commit and report that no PR was opened.

Stay on the task branch when done.
Report the branch name, the PR URL, and any unaddressed review findings.
