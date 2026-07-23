## What to build

Tidy the module tree so a Module's option namespace mirrors its directory under `modules/`, adopt that as a documented convention, group the agent-related Modules under a new `agents/` directory, bring `desktop/hyprland/` into conformance, and drop the obsolete reference Module.

The convention: a Module's option path mirrors its directory path, and a file whose name matches its directory is that directory's index node — it declares the directory's own segment (its `enable`/aggregator) rather than a doubled segment. A file `foo.nix` in directory `d/` declares `modules.<…>.d.foo`. A group directory with no matching index file contributes a namespace segment but no aggregate `enable`.

Applying it:

- **Agents grouping.** Relocate the agent Modules under `modules.agents.*`: `claude-code` (its whole directory, assets included) → `modules.agents.claude-code`; `pi` flattened from its directory to a single file → `modules.agents.pi`; the skills Module renamed from `agent-skills` → `agents/skills.nix`; and `gitea-axi` into an `agents/tools/` subgroup → `modules.agents.tools.gitea-axi`. `tools/` is a real namespace segment, not a cosmetic folder.
- **No aggregators.** `agents/` and `tools/` are pure namespace prefixes — no `modules.agents.enable` or `modules.agents.tools.enable`. Agents are enabled à la carte.
- **Skills stays enable-less.** The skills Module keeps its current behaviour (unconditionally wires `programs.agents.skills`, empty list); it is the one deliberate exception to the Enable convention, marked as intentional by a self-contained comment in the file.
- **Desktop conformance.** Nest `hypridle` and `hyprlock` under `modules.desktop.hyprland.*` (matching the index-file rule, `hyprland.nix` being the index), and update `desktop.nix`'s aggregator to the new paths. The 13 flat `desktop/*.nix` Modules keep their `modules.desktop.<name>` names — broader semantic regrouping is explicitly out of scope for this task.
- **Remove the example Module.** Delete `modules/example.nix`; the documented convention and the many real Modules supersede its teaching role.

Also update the one Host that carries these Modules and the live documentation, and record the convention in the domain model.

## Acceptance criteria

- [x] `CONTEXT.md` gains a `Namespace convention` glossary entry stating the directory-mirrors-namespace rule and the index-file rule, in glossary style (no implementation detail).
- [x] An ADR (next number: `0004`) records the decision — nested-mirrors-directory over flat names, a subfolder as a real namespace segment, the index-file rule, and no `agents` aggregator — following the ADR format.
- [x] Agent Modules resolve under `modules.agents.*`: `modules.agents.claude-code.enable`, `modules.agents.pi.enable`, and `modules.agents.tools.gitea-axi.enable` exist; `modules.claude-code`, `modules.pi`, and `modules.gitea-axi` no longer resolve.
- [x] The skills Module lives at `agents/skills.nix` (renamed from `agent-skills.nix`), stays enable-less, still wires `programs.agents.skills`, and carries an in-file comment marking the Enable-convention exception as intentional.
- [x] Neither `modules.agents.enable` nor `modules.agents.tools.enable` exists (pure namespace prefixes, no aggregator).
- [x] `claude-code`'s assets (`CLAUDE.md`, `authentication.md`, `hooks/`, `skills/`) travel with the move and its relative references still resolve.
- [x] `desktop/hyprland/`: `modules.desktop.hyprland.hypridle` and `modules.desktop.hyprland.hyprlock` resolve; the old `modules.desktop.hypridle`/`modules.desktop.hyprlock` no longer exist; `desktop.nix` enables the new paths; `modules.desktop.enable` still brings up the whole session.
- [x] `modules/example.nix` is removed and `modules.example` no longer resolves.
- [x] `hosts/neogaia/default.nix` uses the new option paths for claude-code, pi, and gitea-axi.
- [x] The two live `CLAUDE.md` gotchas — the `gitea-axi` install line and the `claude-code` skill-source path — are updated to the new option/path; `.claude/tasks/*` are left unchanged as historical record.
- [x] `nix flake check` builds `checks.x86_64-linux.neogaia` green (moved files staged so evaluation sees them).
