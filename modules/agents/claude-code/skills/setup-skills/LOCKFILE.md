# Skills Lockfile

`.claude/skills-lock.yaml`, at the root of a project, tracks which library
skills (from `~/.claude/skills/library/`) have been copied into that
project's `.claude/skills/`, so [`setup-skills`](SKILL.md),
[`update-skills`](../update-skills/SKILL.md), and
[`remove-skills`](../remove-skills/SKILL.md) all agree on what's installed
without re-deriving it from the filesystem.

## Schema

A YAML list of entries, one per installed skill:

```yaml
- name: nbdev
  hash: 3f2a9b8c1d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a
- name: terraform-conventions
  hash: 9c1d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a3f2a9b
```

- `name` — matches both the skill's directory name in the library
  (`skills/library/<name>`) and its copied directory name in the project
  (`.claude/skills/<name>`).
- `hash` — the output of `hash-dir.sh` run against that one skill's
  directory contents, recorded at the moment it was last copied or
  confirmed up to date. Never a hash of anything else — not the whole
  project, not the whole library, just that one skill's own directory
  tree.

## What a mismatch means

To classify a skill's state, compare three values: the lockfile's stored
`hash`, `hash-dir.sh` on the project's current copy
(`.claude/skills/<name>`), and `hash-dir.sh` on the library's current
source (`~/.claude/skills/library/<name>`).

| stored vs. project copy | stored vs. library source | meaning                              |
|--------------------------|----------------------------|--------------------------------------|
| match                     | match                      | nothing to do                        |
| match                     | differs                    | library moved on — safe to update    |
| differs                   | match                      | project customized on purpose — leave it |
| differs                   | differs                    | conflict — report, don't touch       |

## Writing to the lockfile

- Adding a skill: append a new `{name, hash}` entry.
- Applying a safe update: overwrite that entry's `hash` in place with the
  library's current hash.
- Removing a skill: delete its entry entirely.

Never reorder or restructure existing entries beyond what an add, update,
or remove requires — this file is meant to diff cleanly in a project's
git history.
