---
spec: laptop-mvi
blocked-by: 0001-skeleton-and-building-host
---

## What to build

Install Claude Code declaratively on `neogaia`, and make it authenticatable without a browser on the laptop so it can be used over the console/SSH via the paste-code flow or an API key.

## Acceptance criteria

- [x] Claude Code is installed declaratively (following the `Enable convention` if expressed as a `Module`) and enabled on `neogaia`.
- [x] The browserless authentication path (paste-code flow or API key) is documented so it works over console/SSH.
- [x] The `neogaia` toplevel still builds with Claude Code included.

## Implementation Notes

- **Native home-manager module, not a raw package.** Claude Code is enabled through home-manager's own `programs.claude-code` module (`home-manager.users.<user>.programs.claude-code.enable = true`), mirroring how `tmux`/`fish` use their native home-manager options rather than dropping a package into `home.packages`. The module ships within home-manager itself, so — unlike `nvim`/nixvim — no new flake input is needed. Per the invocation's steer to prefer the tmux/nvim conventions over the task wording, the feature `Module` at `modules/claude-code/claude-code.nix` is kept as thin as the `tmux` module: just the `enable` option and the delegation.
- **No settings written.** The module manages no `~/.claude` contents and writes no `settings.json`, so login and first-run configuration stay interactive. This keeps auth material (subscription token or API key) out of the repo.
- **Auth docs co-located with the module.** The browserless authentication guide lives at `modules/claude-code/authentication.md`, next to the module, following the repo pattern where each module directory holds its own supporting files. It covers both the paste-code OAuth flow (open the printed URL on another device, paste the code back — works unchanged over SSH) and the `ANTHROPIC_API_KEY` path. This is distinct from task 0009's OS-install docs, which cover `disko-install`, not the CLI login.
- **Verification.** `nix build .#checks.x86_64-linux.neogaia` (the primary Host seam) builds the toplevel with `claude-code-2.1.209` included; `config.modules.claude-code.enable` and the home-manager `programs.claude-code.enable` both evaluate `true`.
- **Note on flake evaluation.** The new module file had to be `git add`ed before the flake could see it — flakes evaluate the git tree, so an untracked Module is invisible to the Auto-loader and the host errors with "option does not exist".
