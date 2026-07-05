---
name: to-tasks
description: Break a plan or spec into independently-grabbable task files under .claude/tasks/ using tracer-bullet vertical slices.
disable-model-invocation: true
---

# To Tasks

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a spec path, task-folder path, or other reference as an argument, read it directly.

Determine the feature-slug this breakdown belongs to, if any: if a spec file is in context or was passed as an argument, derive it from the filename (`.claude/spec/<feature-slug>.md` → `<feature-slug>`) for each task's `spec` field — see [TASK-FORMAT.md](./TASK-FORMAT.md) for the field's rules. If no spec file exists, proceed without one.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Task titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the plan into **tracer bullet** tasks — vertical slices, not horizontal layers.

<vertical-slice-rules>

- Each slice delivers a narrow but COMPLETE path through every layer the change requires (schema, API, UI, tests), never a horizontal slice of just one
- A completed slice is demoable or verifiable on its own
- Any prefactoring should be done first

</vertical-slice-rules>

### 4. Quiz the user

Number slices with a single sequence shared across every file already in `.claude/tasks/`: scan for the highest existing `NNNN` (four-digit, zero-padded lowercase hex, `0000`-`ffff`) and increment from there. Never restart the sequence per feature and never reuse a number.

Present the proposed breakdown as a numbered list. For each slice, show:

- **File**: the `NNNN-slice-slug` it will be written as, per the numbering above
- **Blocked by**: which other slices (if any) must complete first — "None" if it can start immediately
- **User stories covered**: which user stories this addresses (if the source material has them)

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?

Iterate until the user approves the breakdown, including the proposed numbers and slugs.

### 5. Write the task files

For each approved slice, write a file to `.claude/tasks/<NNNN>-<slice-slug>.md` (create the directory if it doesn't exist) using the numbers and slugs approved in step 4. Use the template in [TASK-FORMAT.md](./TASK-FORMAT.md).

Do NOT modify the parent spec file (`.claude/spec/<feature-slug>.md`) when writing tasks.
