---
spec: laptop-mvi
blocked-by: 0001-skeleton-and-building-host
---

## What to build

A fish `Module`, configured natively via home-manager, that makes the shell feel like the current CachyOS setup but is correct for NixOS. Translate the existing `cachyos-config.fish` and the rest of the fish snapshot under `reference/home/.config/fish/`: the greeting, the bat-manpager, the `done` and bang-bang plugins, the helper functions, and the eza/nav aliases. Drop or replace every Arch/pacman-specific part with its NixOS equivalent. Set fish as the default login shell.

Configure the plugins natively through home-manager rather than a fish plugin manager.

## Acceptance criteria

- [x] A fish `Module` (following the `Enable convention`) is enabled on `neogaia` and configured natively via home-manager.
- [x] The greeting, bat-manpager, `done` and bang-bang plugins, helper functions, and eza/nav aliases from the reference config are reproduced.
- [x] All Arch/pacman-specific parts are dropped or replaced with NixOS equivalents.
- [x] fish is the user's default login shell.
- [x] The `neogaia` toplevel still builds with the fish `Module` enabled.

## Implementation Notes

- **Plugins are native, not inlined.** `done` and `bang-bang` come from `pkgs.fishPlugins.*` via `programs.fish.plugins`; home-manager drops them into `~/.config/fish/conf.d/` where fish auto-sources them.
  The reference config inlined the bang-bang `__history_previous_command` functions and binds by hand; the plugin supplies those, so they are not re-inlined.
- **`done` tuning uses `set -g`, not `set -U`.** The reference set `__done_min_cmd_duration`/`__done_notification_urgency_level` as universal variables, which persist to the universal-variable file and then ignore config changes.
  A declarative config must own these each session, so they are set global (`set -g`) in `interactiveShellInit`.
- **Arch/pacman aliases dropped:** `grubup`, `fixpacman`, `mirror` (`cachyos-rate-mirrors`), `apt`/`apt-get` (`man pacman`), `big` (`expac`), `gitpkg`, `rip` (`expac`).
  **Replaced with NixOS equivalents:** `update` → `sudo nixos-rebuild switch` (was `pacman -Syu`), `cleanup` → `sudo nix-collect-garbage -d` (was `pacman -Rns`).
- **Machine-specific PATH hacks dropped, per spec story 6 ("no impure environment lookup").** The hardcoded `BUN_INSTALL`, the `node-v24...` tarball path, and `~/Applications/depot_tools` from `config.fish` are absolute/impure and are not reproduced; such tooling should be Nix-provided when its own Module arrives.
  The portable bits are kept: `~/.local/bin` on PATH (guarded) and sourcing `~/.fish_profile`.
- **`env.fish` and `rustup.fish` deliberately not carried over.** `ANDROID_HOME`/platform-tools (Android SDK) and `source ~/.cargo/env.fish` (rust) are dev-toolchain integrations outside the MVI's core tooling (fish/tmux/nvim/Claude Code); they belong to future per-toolchain Modules that provide those tools through Nix rather than sourcing an impure env file.
- **`hw` (`hwinfo --short`) and `tb` (`nc termbin.com 9999`) dropped.** These are generic rather than pacman-specific, but each needs an extra package (`hwinfo`, a `netcat`) that the minimal install does not otherwise pull in; left out of the MVI and easy to add later.
- **`copy` kept verbatim** (including the upstream `trim-right` call) to preserve exact parity with the current shell.
- **Verification.** The `neogaia` system toplevel builds (the spec's primary seam).
  The rendered `~/.config/fish/` was inspected in the build output: aliases, the three helper functions, the `fastfetch` greeting, the bat manpager, the `done` tuning vars, and the `conf.d/plugin-done.fish` + `conf.d/plugin-bang-bang.fish` plugin files are all present; `users.users.alexion.shell` resolves to `pkgs.fish`.

### Post-review adjustments

- **`defaultShell` option.** Setting fish as the login shell moved behind `modules.fish.defaultShell` (default `false`, gated with `mkIf`); `neogaia` opts in explicitly. Enabling the Module alone no longer changes the login shell.
- **Abbreviation-first.** Every non-eza alias is now a `shellAbbr` (the eza `ls` family stays an alias), `preferAbbrs = true`, and `generateCompletions = true` is pinned rather than left to the upstream default.
- **vi command-line editing.** `interactiveShellInit` sets `fish_key_bindings fish_vi_key_bindings`; the `bang-bang` plugin re-binds `!`/`$` in insert mode via its own `--on-variable fish_key_bindings` handler, so the switch keeps them working.
- **Trimmed aliases.** Navigation capped at four dots (`.....`/`......` dropped); `psmem`, `psmem10`, `dir`, `vdir`, and `please` removed.
- **Module directory mirrors `~/.config/fish/`.** The Module lives at `modules/fish/fish.nix` with its hand-written fish laid out as in a real fish config: `config.fish` (the whole interactive init, read into `interactiveShellInit`) and `functions/copy.fish` (the non-trivial `copy` body, read into the `functions` option). Trivial one-liner functions stay inline in `fish.nix`. Everything Nix assembles at build time — nothing of ours is autoloaded from a separate runtime file — so the `done` plugin tuning stays inside `config.fish` rather than a `conf.d` fragment (`conf.d` would only earn its name if fish autoloaded it at runtime). `functions/copy.fish` is the sole exception, because fish autoloads function files lazily and that is the idiomatic home for a function. `completions/`/`themes/`/`conf.d/` are omitted as they hold no content of ours and git cannot track empty directories. The Auto-loader only collects `.nix`, so every `.fish` file is inert to it.
