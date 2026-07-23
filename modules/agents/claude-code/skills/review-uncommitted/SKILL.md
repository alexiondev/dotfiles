---
name: review-uncommitted
description: Review the working tree's uncommitted changes along three axes — change risk, repo standards, and spec fidelity — using parallel sub-agents.
---

Three-axis review of the diff between `HEAD` and the working tree:

- **Risk** — how much attention does this change warrant, from low to high?
- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating PRD or task file?

All three axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

## Process

### 1. Capture the diff

The diff command is `git diff HEAD` — everything uncommitted, staged or not.
New files must already be tracked (`git add`ed) to show up; this skill doesn't scan for untracked files, so that's the caller's responsibility.

Confirm the diff is non-empty before going further.
An empty diff should fail here — not inside three parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. A path the user passed as an argument.
2. A spec file matching the branch name or feature — `.claude/spec/<feature-slug>.md`.
3. If nothing is found, ask the user where the spec is.
   If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below — a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing.
Two rules bind it:

- **The repo overrides.**
  A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.**
  Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation — and, like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or holds.
  → rename it; if no honest name comes, the design's murky.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change.
  → extract the shared shape, call it from both.
- **Feature Envy** — a method that reaches into another object's data more than its own.
  → move the method onto the data it envies.
- **Data Clumps** — the same few fields or params keep travelling together (a type wanting to be born).
  → bundle them into one type, pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves its own type.
  → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs across the change.
  → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forces scattered edits across many files in the diff.
  → gather what changes together into one module.
- **Divergent Change** — one file or module is edited for several unrelated reasons.
  → split so each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't have.
  → delete it; inline back until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on.
  → hide the walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward.
  → cut it, call the real target direct.
- **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it inherits.
  → drop the inheritance, use composition.

### 4. Risk rubric

The Risk axis judges the diff alone — no repo-doc lookup, no input from the Standards or Spec sub-agents.
It always runs; it only needs the diff from step 1.

Rate each of these six factors **Low / Medium / High**, then take the single highest-rated factor as the overall rating (worst-factor-wins):

- **Blast radius** — isolated change vs. ripples across many files, modules, or callers.
- **Reversibility** — trivial rollback vs. hard to undo (migrations, deletions, published API/schema changes).
- **Test coverage** — covered by tests in/around the diff vs. untested.
- **Sensitive domain** — touches auth, security, payments, permissions, concurrency, or data migrations.
- **Size & complexity** — large diff or tangled control flow vs. small/simple.
- **Runtime criticality** — hot path/production-critical vs. internal or dev-only tooling.

### 5. Spawn all three sub-agents in parallel

Send a single message with three `Agent` tool calls.
Use the `general-purpose` subagent for all three.

**Risk sub-agent prompt** — include:

- The full diff (output of `git diff HEAD`).
- The six risk factors from step 4, pasted in full.
- The brief: "Rate each of the six factors Low/Medium/High with a one-clause reason, then give the overall rating as the highest of the six.
  Report the overall rating first, then the six factor lines.
  Under 200 words."

**Standards sub-agent prompt** — include:

- The full diff (output of `git diff HEAD`).
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full — the sub-agent has no other access to it.
- The brief: "Report — per file/hunk where relevant — (a) every place the diff violates a documented standard: cite the standard (file + the rule); and (b) any baseline smell you spot: name it and quote the hunk.
  Distinguish hard violations from judgement calls — documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline.
  Skip anything tooling enforces.
  Under 400 words."

**Spec sub-agent prompt** — include:

- The full diff (output of `git diff HEAD`).
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong.
  Quote the spec line for each finding.
  Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 6. Aggregate

Present the Risk report first, under a `## Risk` heading, with the overall rating bolded on its own line followed by the six factor lines:

```
## Risk
**Overall: HIGH**
- Blast radius: ...
- Reversibility: ...
- Test coverage: ...
- Sensitive domain: ...
- Size & complexity: ...
- Runtime criticality: ...
```

Then present the Standards and Spec reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned.
Do **not** merge or rerank findings — the axes are deliberately separate (see _Why Standards and Spec stay separate_).

End with a one-line summary: total findings per axis (Standards/Spec only), and the worst issue _within each axis_ (if any).
Don't pick a single winner across axes — that's the reranking the separation exists to prevent.
The risk rating isn't repeated here; it already leads the report.

## Why Standards and Spec stay separate

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the PRD or task asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
