---
name: remove-skills
description: Remove one or more previously added library skills from the current project.
disable-model-invocation: true
---

Removes a skill that [`setup-skills`](../setup-skills/SKILL.md) previously
copied into the current project, deleting both its files and its entry in
`.claude/skills-lock.yaml` (see [LOCKFILE.md](../setup-skills/LOCKFILE.md)
for its schema).

## Steps

1. Read `.claude/skills-lock.yaml`. If it doesn't exist or is empty, tell
   the user there's nothing installed to remove and stop.

2. Determine which skill(s) to remove:
   - If the user's invocation already named a specific skill, use that —
     if it isn't in the lockfile, say so and stop.
   - Otherwise, list every skill currently in the lockfile and ask the
     user to pick one (or more).

3. For each skill to remove, compute its current hash
   (`~/.claude/skills/setup-skills/hash-dir.sh .claude/skills/<name>`)
   and compare it to the hash stored in the lockfile:
   - If it matches (never modified since it was installed), delete
     `.claude/skills/<name>/` and remove its lockfile entry immediately —
     no confirmation needed, since nothing of the user's is being lost.
   - If it differs (locally customized), tell the user it has local
     changes that will be permanently lost and ask for confirmation
     before deleting. If they decline, leave that skill installed and
     move on to the next.

4. Finish with a summary of what was removed and what was left in place.

Done when every skill to remove has been either deleted (with its lockfile
entry removed) or explicitly left in place with a stated reason.
