---
name: craft-skill
description: Draft a new skill, or audit and rewrite an existing one, judged against the vocabulary in GLOSSARY.md.
disable-model-invocation: true
---

Draft a new skill from scratch, or audit and rewrite an existing one — both judged against one bar: **predictability**, the agent taking the same process every run. **Bold terms** are defined in [`GLOSSARY.md`](GLOSSARY.md); look them up there for the full meaning.

This skill does not judge general prose quality (clarity, jargon, sentence structure) — only skill-specific structure. A dedicated technical-writing-guide skill will cover the former once it exists; until then, use your own judgment for sentence-level prose.

## Which branch

If the request describes a new workflow, capability, or repeated manual process with no existing skill named — **Draft a new skill**. If it names an existing skill (by name or path) to review, fix, or improve — **Audit an existing skill**. Both end at **Verify and ship**.

## Draft a new skill

1. **Capture intent.** If the conversation already contains the workflow (e.g. "turn this into a skill"), extract answers from it first; only ask about what's missing. Ask one question at a time — several at once is bewildering:
   - What should this make the agent do — is it a **procedure** (ordered **steps**), **knowledge** it consults (**reference**), or both? This decides the shape from the start.
   - When would you actually reach for it: do you type its name, or should the agent reach for it unprompted? Walk the **context load** vs **cognitive load** tradeoff explicitly rather than defaulting — see `Invocation` in GLOSSARY.md.
   - Does it have distinct **branches** — cases that take different paths? Name each. A linear checklist's items aren't branches by themselves — look for actual alternate paths, not the steps that always all run.
   - Is this workflow already documented somewhere in the project (a README, CLAUDE.md, CONTRIBUTING)? If so the draft should point there rather than restate it — see `External Reference` and `Single Source of Truth` in GLOSSARY.md.
   - For each step, what does done look like — a **completion criterion** you could check without ambiguity?
   - Is there already a word — in your prompts, docs, or codebase — that names this behavior? Reach for that **leading word** before coining one.
   Done when every axis above has an answer, or the user says to just draft something and iterate.

2. **Write the draft.** First decide where it lives: project-local `.claude/skills/` if the workflow is tied to this one repo, the personal set if it's general-purpose across projects. The personal set is not authored in `~/.claude/skills/` — that tree is generated, and every file under it is a read-only symlink into the Nix store. Write it in the dotfiles repo at `modules/claude-code/skills/<name>/` and rebuild to make it live. Creating files directly under `~/.claude/skills/` looks like it works, because the directories themselves are writable, but the result is untracked by the repo and reaches no other machine. Then follow the **information hierarchy**: steps for what the agent does in order, in-file **reference** for facts every branch needs, and disclose the rest behind a pointer — to a sibling file, or to the existing project docs identified in step 1 rather than restating them. Done when every branch from step 1 has somewhere to live, and no sentence fails the no-op test in isolation (see `No-Op` in GLOSSARY.md).

## Audit an existing skill

1. **Locate it.** Check the current project's `.claude/skills/`, then `~/.claude/skills/`, then `~/.claude/skills/library/`, in that order; ask if the name is ambiguous across locations. A hit under `~/.claude/skills/` is a read-only symlink and cannot be edited in place: its source is the dotfiles repo, at `modules/claude-code/skills/<name>/` for a personal skill or `modules/claude-code/skills/library/<name>/` for a library one. Edit there and rebuild. If it's tracked in a project's `skills-lock.yaml`, mention that editing it here will make it read as locally-customized to `update-skills` — confirm that's actually intended rather than editing the library source.

2. **Apply the checklist.** Read the skill and its disclosed files, then check each against GLOSSARY.md, quoting the offending line for anything that fails:
   - **Premature completion** — is each completion criterion checkable, and does it demand what the step actually needs?
   - **Duplication** — does any meaning appear in more than one place?
   - **Sediment** — any line that no longer bears on what the skill does?
   - **Sprawl** — could in-file reference be disclosed instead, or a run of steps split by branch?
   - **No-op** — any sentence the model would already do by default? Test sentence by sentence, not line by line — a line can carry one load-bearing sentence and one no-op sentence together.
   - Is the **invocation** choice (model- vs user-invoked) still the right one for how this skill actually gets used? Is there a restated concept that should collapse into a **leading word**?

3. **Rewrite** based on the findings. Done when every finding from step 2 is either addressed or explicitly noted as intentionally kept.

## Verify and ship

1. Propose one realistic test prompt — reflecting the trigger phrasing gathered (draft) or the skill's existing purpose (audit) — and get it confirmed or adjusted before spending a run on it.
2. Spawn one subagent: give it the skill's path and the confirmed prompt, have it attempt the task using the skill, and report back what happened — including anywhere it hesitated, misread the skill, or did something unexpected.
3. Re-read the draft/rewrite against GLOSSARY.md's failure modes in light of that run, and fix whatever either pass turned up. If the fix is substantial, repeat from step 1; otherwise it's done.
4. Stage the specific changed or created paths — one path per file, never a wildcard — with `git add <path>`. Do not commit; that's left to the user.

Done when the subagent's run succeeded without confusion on the confirmed prompt, the checklist raised nothing outstanding, and every changed path is staged.
