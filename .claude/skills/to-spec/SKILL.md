---
name: to-spec
description: Turn the current conversation into a spec and write it to .claude/spec/ — no interview, just synthesis of what you've already discussed.
disable-model-invocation: true
---

This skill takes the current conversation context and codebase understanding and produces a spec. Do NOT interview the user — just synthesize what you already know.

If the conversation doesn't actually contain a feature or problem to synthesize a spec from, say so and ask what it's for instead of fabricating one.

## Process

1. Explore the repo until you can name the existing modules, flows, and seams the feature will touch, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, propose them at the highest point you can. The fewer seams across the codebase, the better - the ideal number is one.

Check with the user that these seams match their expectations.

3. Derive a short kebab-case feature-slug from the feature's name (e.g. `checkout-flow`). Tell the user the path you're about to write to (`.claude/spec/<feature-slug>.md`). If a file already exists there, summarize what would change and confirm with the user before overwriting it — never overwrite silently.

4. Write the spec using the format in [SPEC-FORMAT.md](./SPEC-FORMAT.md) to `.claude/spec/<feature-slug>.md`, creating the `.claude/spec/` directory if it doesn't exist yet.
