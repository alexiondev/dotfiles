# Task Format

## Template

```md
---
spec: <feature-slug>
blocked-by: <slice-slug-or-list>
---

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3
```

## Rules

- **`spec`**: the feature-slug this task was written from. Omit the field entirely if there's no spec.
- **`blocked-by`**: which other task(s) must complete before this one can start. Omit the field entirely if there are none. A single blocker is a bare string (`blocked-by: 000a-add-schema`); more than one is a YAML list (`blocked-by: [000a-add-schema, 000b-wire-api]`). Once written, keep the field even after the referenced task is completed — it's a permanent record of the dependency, not a "still blocked" flag.
- **Don't include specific file paths or code snippets** in "What to build" — they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it here and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.
- A task is done when every criterion in "Acceptance criteria" is resolved: mark `[x]` as satisfied, or `[-]` if deliberately dropped (`/implement` records the reason in the task's Implementation Notes) — track completion here, not anywhere else.
- A slice becomes pickable once every task named in `blocked-by` is done (all of its acceptance criteria resolved) — check the referenced tasks' state, not just whether the field is present. The file's number is an identifier and a rough ordering hint, not a strict gate — sibling slices with no blockers can be worked in parallel.
