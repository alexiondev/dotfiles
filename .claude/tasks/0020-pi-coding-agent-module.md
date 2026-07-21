---
spec: pi-coding-agent
---

## What to build

Add a `pi` module, auto-discovered like every other feature and inert until a host enables it, that installs Pi for the primary user through the home-manager `programs.pi-coding-agent` module.
On enable it freezes exactly one file — `settings.json` — pinning the default provider to Anthropic and the default model to Opus (the exact model-id string confirmed against Pi's own model catalogue), and disabling analytics.
Everything else — agent context, skills, extensions, keybindings, custom providers — is left at its default, so home-manager renders nothing but `settings.json` and Pi owns the rest of `~/.pi/agent/`.
Pi authenticates by reusing the existing Claude subscription, and that credential is left unmanaged by the flake so no secret enters the repo and re-auth survives rebuilds, mirroring how the `claude-code` module treats its login.
Lay the module out as a directory (not a single file), and enable it on `neogaia` alone with a single `enable = true`.

## Acceptance criteria

- [x] A `pi` module exists as its own directory, declares a single `enable` option under the `modules` tree, guards its body with the Enable convention, and stays inert until a host enables it.
- [x] On enable, the module turns on `programs.pi-coding-agent` for the primary user from the base package set, with no other host affected.
- [x] The frozen `settings.json` sets the default provider to Anthropic, the default model to Opus (exact model-id verified against Pi's catalogue), and disables analytics — and no other upstream option (`context`, `models`, `keybindings`, `extraPackages`, `configDir`) is set.
- [x] Pi's credential and all of its writable state (`~/.pi/agent/` beyond `settings.json`) are left unmanaged by the flake.
- [x] `neogaia` enables the module with a single `enable = true` and its system toplevel still builds via `nix flake check` (the `checks.x86_64-linux.neogaia` target).
- [x] Disabling the module is a one-line `enable` flip that leaves no flake-managed residue.

## Implementation Notes

- **Model-id and analytics key confirmed against Pi 0.80.7 at build time.** The `pi-coding-agent` package pins `0.80.7`; its `dist/core/model-resolver.js` defaults the `anthropic` provider to `claude-opus-4-8`, which is the Opus id used. The analytics key is `enableAnalytics` (boolean, default `false`), per the package's own `docs/settings.md`. Both were read from the built store path, not guessed.
- **Verified through the primary seam.** `config.modules.pi.enable` and `programs.pi-coding-agent.enable` both evaluate `true` on `neogaia`; the rendered `settings.json` is exactly `{"defaultModel":"claude-opus-4-8","defaultProvider":"anthropic","enableAnalytics":false}`; only one file (`settings.json`) is rendered under `~/.pi/agent`; and `checks.x86_64-linux.neogaia` builds green with `pi-coding-agent-0.80.7` included.
- **No deviations from the spec.** The diff is the module plus one `enable = true` line — every "Out of Scope" item (agent context/`AGENTS.md`, skills, extensions, keybindings, custom providers, Pi-specific sudo guard) is left out.
- **Review follow-through.** `/review-uncommitted` rated Risk **Low** and Spec **clean**. Standards flagged four comment-convention issues on the new module (a semicolon in a comment, an overloaded file-top header duplicating the inline rationale, and a cross-file clause on the model-id comment); all were fixed in the diff, so the header is now a two-sentence purpose line mirroring the sibling `claude-code` module and the frozen-settings rationale lives only at its inline site. No findings left unaddressed.
