---
name: implement
description: Implement a task file produced by /to-tasks, review it, and close it out.
disable-model-invocation: true
---

Implement a task file end-to-end: build it, review it, and close it out.

## Process

### 1. Read the task file and check blockers

The user passes the path to a task file (`.claude/tasks/<NNNN>-slug.md`, as produced by `/to-tasks`) explicitly — don't infer one from context.

If the task's frontmatter has a `blocked-by` field, read each referenced task file and check for any unresolved `- [ ]` acceptance criterion. If any blocker isn't fully resolved, warn the user which one and why, and confirm before proceeding — don't refuse outright.

### 2. Implement

Build the work described in the task's "What to build" section, satisfying its acceptance criteria. Use `/test-driven-development` where possible, at the seams already agreed when the spec or task was written.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

### 3. Stage the changes

Stage (`git add`) each file you create or modify, specifically — not `git add -A` — so nothing untracked and unrelated gets swept in.

### 4. Review

Run `/review-uncommitted`, passing the task file itself as the spec source — it already links back to its parent spec via its `spec` frontmatter field, if any. Address anything it raises before moving on.

### 5. Close out the task file

Mark every acceptance criterion `[x]` if satisfied or `[-]` if deliberately dropped, so none are left `[ ]`. Append a `## Implementation Notes` section explaining any deviations from the plan — dropped criteria (referencing which, and why), scope changes, decisions made mid-implementation, follow-ups worth flagging. Skip the section only if nothing deviated. Leave the `spec` and `blocked-by` frontmatter fields untouched — they're a permanent record, not a checklist to clear (see `to-tasks`'s `TASK-FORMAT.md`).

Stage the updated task file with the rest.

Do not commit — leave the commit itself for the user to make.
