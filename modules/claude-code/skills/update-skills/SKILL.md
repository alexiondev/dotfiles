---
name: update-skills
description: Check the current project's installed library skills for upstream changes and apply the safe ones.
disable-model-invocation: true
---

Compares every skill listed in the current project's
`.claude/skills-lock.yaml` (see [LOCKFILE.md](../setup-skills/LOCKFILE.md)
for its schema) against both the project's own copy and the current
library source, and decides what to do about each one. Never installs a
skill that isn't already there — that's
[`setup-skills`](../setup-skills/SKILL.md)'s job.

## Steps

1. Read `.claude/skills-lock.yaml`. If it doesn't exist or is empty, tell
   the user there's nothing to check and stop.

2. For each `{name, hash}` entry, compute:
   - `project_hash`: `~/.claude/skills/setup-skills/hash-dir.sh .claude/skills/<name>`
   - `library_hash`: `~/.claude/skills/setup-skills/hash-dir.sh ~/.claude/skills/library/<name>`

   If either path is missing entirely, report that anomaly for this skill
   (don't try to classify it) and move on to the next entry.

3. Classify each entry against the table in
   [LOCKFILE.md](../setup-skills/LOCKFILE.md#what-a-mismatch-means),
   using `project_hash` in place of "project copy" and `library_hash` in
   place of "library source". The two outcomes that need action below are
   **safe update** (stored matches project, differs from library) and
   **conflict** (stored differs from both). "Locally customized" needs no
   message beyond the summary.

4. If there are any safe updates, list them by name and ask for one
   confirmation to apply all of them — unless the user's invocation
   already included an explicit go-ahead argument (e.g. `-y`, `yes`), in
   which case apply them without asking. Applying means: delete
   `.claude/skills/<name>/` entirely and copy
   `~/.claude/skills/library/<name>/` in its place, so no file the project
   copy had but the library no longer has can survive — then recompute its
   hash and overwrite that entry's `hash` in `.claude/skills-lock.yaml` in
   place.

5. For every conflict, report it and show a recursive diff between the
   project's copy and the library's current version
   (`diff -ru .claude/skills/<name> ~/.claude/skills/library/<name>`).
   Do not modify the project's copy or the lockfile entry for a
   conflicted skill under any circumstances — surfacing it is the whole
   job here.

6. Finish with a summary: updated, left alone (customized), conflicted,
   already current, and any anomalies from step 2.
