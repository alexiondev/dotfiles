---
status: accepted
---

# A Module's option namespace mirrors its directory

A Module's option path mirrors its directory path under `modules/`, so a file's location on disk is its namespace: `modules/agents/tools/gitea-axi.nix` declares `modules.agents.tools.gitea-axi`, and a subfolder like `agents/` or `tools/` is a real namespace segment, not a cosmetic grouping.
A file whose name matches its enclosing directory is that directory's index node, declaring the directory's own segment — its `enable` or aggregator — rather than a doubled segment, so `desktop/hyprland/hyprland.nix` owns `modules.desktop.hyprland` while `desktop/hyprland/hypridle.nix` nests under it as `modules.desktop.hyprland.hypridle`.

We chose this nested-mirrors-directory shape over the previous flat names (`modules.claude-code`, `modules.gitea-axi`) because the flat scheme let a Module sit anywhere on disk regardless of its option path, so the tree stopped predicting where a namespace lived.
Mirroring makes the two the single fact.
A pure grouping directory (`agents/`, `tools/`) contributes a namespace segment but declares no aggregate `enable`: agents are enabled à la carte, so there is deliberately no `modules.agents.enable` that would turn on a bundle nobody wants as a unit.

## Considered Options

- **Flat, location-independent names** (the prior state). Rejected: a Module's option path was unconstrained by its file's location, so the directory tree and the option tree drifted and neither could be read off the other.
- **A subfolder as cosmetic grouping only**, with the option path skipping the folder (`agents/pi.nix` → `modules.pi`). Rejected: it reintroduces the same drift for grouped Modules and makes the folder a lie the namespace does not tell.
- **An aggregator at every grouping level** (`modules.agents.enable`). Rejected: the agent Modules have no meaningful "all agents" bundle, and an aggregate enable there would invite turning on tools no Host wants together.

## Consequences

- The `agents/` group carries `claude-code`, `pi`, `skills`, and `tools/gitea-axi`, each enabled individually under `modules.agents.*`, with no `modules.agents.enable`.
- The index-file rule means adding a knob to an existing group (a new `desktop/hyprland/*.nix`) nests automatically without a naming decision, while a new top-level Module names its own segment.
- The `skills` Module remains the one deliberate exception to the Enable convention — it wires unconditionally — which the namespace convention does not change.
