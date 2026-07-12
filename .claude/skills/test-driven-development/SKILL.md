---
name: test-driven-development
description: Test-driven development. Use when the user wants to build features or fix bugs test-first, mentions "red-green-refactor", or wants integration tests.
---

# Test-Driven Development

## Philosophy

**Core principle**: Tests should verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't.

**Good tests** are integration-style: they exercise real code paths through public APIs. They describe _what_ the system does, not _how_ it does it. A good test reads like a specification - "user can checkout with valid cart" tells you exactly what capability exists. These tests survive refactors because they don't care about internal structure.

**Bad tests** are coupled to implementation. They mock internal collaborators, test private methods, or verify through external means (like querying a database directly instead of using the interface). The warning sign: your test breaks when you refactor, but behavior hasn't changed. If you rename an internal function and tests fail, those tests were testing implementation, not behavior.

**Tautological tests** restate the implementation inside the assertion, so they pass by construction and give zero confidence. When the expected value is computed the way the code computes it — `expect(add(a, b)).toBe(a + b)`, snapshotting a figure you derived by hand the same way the code does, asserting a constant equals itself — the test can never disagree with the code: break the code wrong and the assertion breaks wrong with it. The expected value must come from an independent source of truth — a known-good literal, a worked example, the spec.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all implementation.** This is "horizontal slicing" - treating RED as "write all tests" and GREEN as "write all code."

This produces **crap tests**:

- Tests written in bulk test _imagined_ behavior, not _actual_ behavior
- You end up testing the _shape_ of things (data structures, function signatures) rather than user-facing behavior
- Tests become insensitive to real changes - they pass when behavior breaks, fail when behavior is fine
- You outrun your headlights, committing to test structure before understanding the implementation

**Correct approach**: Vertical slices via tracer bullets. One test → one implementation → repeat. Each test responds to what you learned from the previous cycle.

The test-writer sub-agent (below) is handed **one behavior at a time** and never sees the behavior backlog, so it can't bulk-write the suite.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

## Roles

Every test is written by a **test-writer sub-agent**. The main agent writes every line of implementation, and never writes or edits a test.

The sub-agent must not read the implementation source of the module under test — that is what keeps its tests from asserting _how_ instead of _what_. It works from the public interface alone.

Use one `general-purpose` sub-agent for the whole task: spawn it at the first RED, then continue it with `SendMessage` for each subsequent RED, so it keeps the test file and conventions it established. Cold-spawn a replacement only if its ID is lost.

### Test-writer sub-agent prompt — include:

- **One behavior**, quoted verbatim from the acceptance criterion or the agreed behavior list. Never the task file, never the rest of the list.
- The **public interface** under test — signatures only.
- The existing test file(s) for the module, and the project's test conventions (fixtures, helpers, runner invocation).
- [tests.md](tests.md) and [mocking.md](mocking.md).
- The **independent source of truth for the expected value** — the spec excerpt, worked example, or known-good literal. Without it the sub-agent recomputes the expected value the way the code would, and the test is tautological.
- `.claude/CONTEXT.md` (if it exists) and any ADRs in the area, so test names and interface vocabulary match the project's domain language.
- The test-side checklist from [Checklist Per Cycle](#checklist-per-cycle), pasted in full — the sub-agent has no other access to it.
- The brief: "Write ONE test for this behavior. Do not read the implementation source of the module under test. Write it to the test file, run it, and confirm it fails with a genuine assertion failure — not an import, syntax, or collection error, which prove nothing. Report the test's name and the exact failure message you saw."

## Workflow

### 1. Planning

When exploring the codebase, read `.claude/CONTEXT.md` (if it exists) so that test names and interface vocabulary match the project's domain language, and respect ADRs in the area you're touching.

Identify opportunities for deep modules (small interface, deep implementation) — run the `/codebase-design` skill for the vocabulary and the testability checks. Do this regardless of what triggered this workflow.

**If a task file is already in context** (e.g. passed to `/implement`, which called this skill), its acceptance criteria are the behavior list to test — the interface and priorities were already agreed during `/to-spec` and `/to-tasks`. Don't re-confirm them with the user; go straight to the tracer bullet.

**Otherwise**, before writing any code:

- [ ] Confirm with user what interface changes are needed
- [ ] Confirm with user which behaviors to test (prioritize)
- [ ] List the behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

Ask: "What should the public interface look like? Which behaviors are most important to test?"

**You can't test everything.** Confirm with the user exactly which behaviors matter most. Focus testing effort on critical paths and complex logic, not every possible edge case.

Planning stays with the main agent on both paths — exploration, interface, and the order behaviors are tested in. The sub-agent receives behaviors one at a time; it never chooses what to test next.

### 2. Tracer Bullet

ONE test that confirms ONE thing about the system:

```
RED:   Spawn the test-writer sub-agent with the first behavior → it writes the test, runs it, reports a genuine failure
GREEN: Main agent writes minimal code to pass → test passes
```

This is your tracer bullet - proves the path works end-to-end.

### 3. Incremental Loop

For each remaining behavior:

```
RED:   SendMessage the same sub-agent the next behavior → it writes the test, runs it, reports a genuine failure
GREEN: Main agent writes minimal code to pass → passes
```

Rules:

- One test at a time
- Only enough code to pass current test
- Don't anticipate future tests
- Keep tests focused on observable behavior

### When a test looks wrong

The main agent never edits a sub-agent-authored test — not to fix an import, not to "simplify" an assertion, not to reach GREEN.

- **Mechanical defect** — bad import path, a fixture or helper that doesn't exist, doesn't parse. Send the error output back to the sub-agent and let it fix its own test.
- **Semantic disagreement** — you believe the expected value or the asserted behavior is wrong. Stop and ask the user. Do not resolve it yourself; this disagreement is the signal the sub-agent exists to surface, and half the time it's the code that's wrong.

### 4. Refactor

After all tests pass, look for [refactor candidates](refactoring.md):

- [ ] Extract duplication
- [ ] Deepen modules (move complexity behind simple interfaces)
- [ ] Apply SOLID principles where natural
- [ ] Consider what new code reveals about existing code
- [ ] Run tests after each refactor step

**Never refactor while RED.** Get to GREEN first.

A test that breaks during refactor means the refactor broke behavior — fix the code. The one exception is a public interface change you made deliberately (a module deepened, a signature moved, as agreed in the plan): send the interface change to the sub-agent and let it update its own tests. There is no case where the main agent edits the test itself.

## Checklist Per Cycle

Test-writer sub-agent, per test — paste into its prompt:

```
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Expected values are independent literals, not recomputed from the code
```

Main agent, per GREEN:

```
[ ] Code is minimal for this test
[ ] No speculative features added
```
