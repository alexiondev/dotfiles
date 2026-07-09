---
name: grill
description: Interview the user relentlessly about a plan or design, capturing the resolved terms and decisions into the project's domain model as you go if one exists. Use when the user wants to stress-test a plan before building, or uses any 'grill' trigger phrase.
---

Interview me relentlessly about every aspect of this plan or design. Walk down each branch of the design tree, resolving dependencies between decisions one by one, and give your recommended answer for each question. Keep going until every branch carries an explicit decision and no dependency between decisions is left open — not merely until it feels like "we understand each other."

Ask the questions one at a time, waiting for feedback on each before continuing. Asking several at once is bewildering.

If a question can be answered by exploring the codebase, explore the codebase instead of asking it.

**Never start implementation during or after the interview without an explicit instruction from the user.** This applies at every point — mid-interview and after the final question alike.

## Closing the interview

When every branch carries an explicit decision and no dependency is left open, produce a concise summary of all decisions reached, then stop and wait for the user's next instruction.

## Tracking the domain model as you go

If a `.claude/CONTEXT.md` file exists in the project, also run [`domain-modeling`](../domain-modeling/SKILL.md) alongside this interview: resolve each term into `.claude/CONTEXT.md` the moment it crystallizes, and offer an ADR using that skill's own criteria — hard to reverse, surprising without context, and the result of a real trade-off. If no `.claude/CONTEXT.md` exists, run the interview alone with no doc side effects.
