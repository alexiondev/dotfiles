---
name: setup-skills
description: Add relevant skills from the shared skills library to the current project.
disable-model-invocation: true
---

Adds opt-in, project-specific skills from `~/.claude/skills/library/` into
the current project's `.claude/skills/`, tracked in
`.claude/skills-lock.yaml` (see [LOCKFILE.md](LOCKFILE.md) for its schema).
Only ever adds — checking already-installed skills for updates is
[`update-skills`](../update-skills/SKILL.md)'s job, not this one's.

## Steps

1. Read `.claude/skills-lock.yaml` in the current project, if it exists.
   Note every skill name already listed — these are already installed and
   must not be re-proposed.

2. List every skill under `~/.claude/skills/library/*/SKILL.md` and read
   each one's `name` and `description`.

3. Inspect the current project (file tree, manifests like
   `pyproject.toml`/`package.json`, file extensions present, etc.) and
   judge which library skills — excluding ones already installed — seem
   relevant, the same way you'd reason about any unfamiliar codebase.
   Propose that shortlist to the user with your reasoning, one line per
   skill. If the user asks to see the full catalog instead, list every
   library skill (minus already-installed ones) with its description.

4. Let the user confirm, adjust, or pick freely from the full list.

5. For each confirmed skill:
   - If `.claude/skills/<name>/` already exists in the project and is
     *not* in the lockfile, skip it and tell the user why (a same-named
     skill already lives there and isn't tracked — remove or rename it
     first if they want the library version).
   - Otherwise, copy `~/.claude/skills/library/<name>/` to
     `.claude/skills/<name>/` in the project, run
     `~/.claude/skills/setup-skills/hash-dir.sh .claude/skills/<name>`,
     and append `{name, hash: <output>}` to `.claude/skills-lock.yaml`
     (create the file, an empty YAML list, if it doesn't exist yet).

6. Report what was added and what was skipped, and why.

Done when every confirmed skill is either copied and recorded in the
lockfile, or explicitly skipped with a stated reason.
