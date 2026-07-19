# dotfiles-nixos

One flake that builds every machine the user owns.
The domain model (Host, Module, Skeleton, Auto-loader, Enable convention, overlays) lives in `.claude/CONTEXT.md`; the current deliverable's spec is `.claude/spec/laptop-mvi.md`.

## Conventions

- Write comments only where they earn their place, and keep them concise.
  Assume the reader can read code: comment the "why", not the "what", and explain "what" only when it is genuinely non-obvious.
  A comment must be self-contained to its file — accurate to a reader looking at that file alone.
  Do not write about history ("used to be X", "now moved here") or future state, about how a value is consumed elsewhere, or to justify the choice against alternatives; state the positive reason a thing exists, keeping any real stakes as a present-tense consequence.
  The only permitted cross-file mention is a bare pointer explaining why something is *absent* here (e.g. "disko derives `fileSystems`; none declared here"), never narrating what the other file or tool does.
  Do not use the domain model's capitalized terms (Host, Module, Skeleton, Auto-loader, Enable convention) as glossary references; describe things in plain language, using "host"/"module" only as ordinary lowercase nouns.
  Never reference agent-facing state (anything under `.claude/` or `CLAUDE.md`).
  A file-top header is one concise purpose line, added only where the filename or path does not already say it — never a feature inventory of the code below.
  For a placeholder, say so plainly plus any actionable present-tense directive ("Placeholder: regenerate with nixos-generate-config on the target machine"), never "placeholder for <missing feature>".
  Option `description`/`mkEnableOption` strings are user-facing documentation rather than comments, so they may describe behaviour more fully — but the self-contained rule and the bans on glossary terms and agent-state references still apply.
- Comments posted to Gitea (pull requests, issues, reviews) go out under the operator's account, so sign every one to make clear the author is the agent, not the operator.
  End the comment with a `— Claude` sign-off.
  (A dedicated bot account may replace this later; until then, the sign-off is the only marker.)
- Commit messages follow Conventional Commits, specified in `docs/conventional-commits.md`.
  Scope is the module or host the change belongs to (`fish`, `nvim`, `neogaia`), omitted for repo-wide changes.
  Keep messages free of Gitea-specific references: this repository is mirrored to GitHub, where issue and pull-request numbers resolve to unrelated things.

## Gotchas

- Nix on the dev host needs experimental features passed per-command.
  This repo is developed on `neogaia` while it still runs **CachyOS** (the migration target), where Nix is the distro package at `/usr/bin/nix` in multi-user daemon mode.
  The system `/etc/nix/nix.conf` does not enable flakes, so export `NIX_CONFIG="experimental-features = nix-command flakes"` (or pass `--extra-experimental-features 'nix-command flakes'`) for every command.
- The dev user is a non-trusted daemon client (`nix store info` reports `Trusted: 0`).
  You cannot add substituters from the CLI, so rely on what the flake/config declares (e.g. the chaotic cache is wired by the chaotic module, not a CLI flag).
  Caveat that bites when a Host actually selects the CachyOS kernel: the substituters a `nix build` fetches from are the **daemon's** (`/etc/nix/nix.conf`), *not* the `nix.settings` of the config being built — those only govern the built system.
  This dev host's `/etc/nix/nix.conf` has no `substituters`/`trusted-substituters` lines, so building a toplevel whose `boot.kernelPackages` is `linuxPackages_cachyos` compiles the kernel (and rustc bootstrap, etc.) from source instead of hitting `nyx-cache`.
  To build such a Host here, first add `extra-substituters = https://nyx-cache.chaotic.cx/` and `extra-trusted-public-keys = nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=` to `/etc/nix/nix.conf` (sudo) and `sudo systemctl restart nix-daemon`.
  `nix eval` of the kernel version does *not* trigger this — only a real build does.
- If `/nix/store` is missing or `nix-daemon` is inactive after a fresh Nix install, initialise it with `sudo systemd-tmpfiles --create nix-daemon.conf && sudo systemctl enable --now nix-daemon.socket`.
- The primary build/verify seam for any Host is `nix flake check`, which builds `checks.x86_64-linux.<host>` (the system toplevel); cheap targeted checks use `nix eval .#nixosConfigurations.<host>.config...`.
- chaotic-nyx must **not** follow our `nixpkgs`, and its packages are built against chaotic's own pinned nixpkgs (its overlay defaults to `onTopOf = "flake-nixpkgs"`, the cache-friendly path).
  That is what lets the `nyx-cache.chaotic.cx` binary cache hit instead of compiling the CachyOS kernel from source; the tradeoff is that chaotic packages do not see our `unstable`/`stable` overlays.
- The remote is self-hosted Gitea (`git.alexion.dev`); the forge CLI is `tea` (login `axi`), and `gh` is not installed.
- nixpkgs `vimPlugins.nord-nvim` is `shaunsingh/nord.nvim` (no `require("nord").setup()`); the config wants `gbprod/nord.nvim`, which is packaged as `vimPlugins.gbprod-nord`.
- nixpkgs `vimPlugins.nvim-treesitter` tracks the rewritten `main` branch: there is no `require("nvim-treesitter.configs").setup{ensure_installed,highlight,indent}`. Under nixvim, use `plugins.treesitter` with `highlight.enable`/`indent.enable` and `grammarPackages = with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [ ... ]` — the module's own `package.builtGrammars`, **not** `pkgs.vimPlugins.nvim-treesitter.*` (whose query files can mismatch). The module targets the main branch and enables features via neovim-native APIs (`vim.treesitter.start()`, `require'nvim-treesitter'.indentexpr()`).
- Neovim is configured via **nixvim** (flake input `nixvim`, consumed as `inputs.nixvim.homeModules.nixvim` added to `home-manager.sharedModules`, config under `home-manager.users.<user>.programs.nixvim`). `nixvim.inputs.nixpkgs.follows = "nixpkgs"` is set; nixvim then emits a benign eval warning that its pinned nixpkgs differs from the followed one — builds and runs fine, do not "fix" it by dropping the follows.
- To reference the nixvim-built package's own attrs (e.g. treesitter `builtGrammars`) inside our NixOS module, give `home-manager.users.<user>` the module-function form (`hm: { programs.nixvim = { ... hm.config.programs.nixvim... }; }`), since the outer `config` is the NixOS config, not the home-manager one.
- **Verifying a nixvim change headless:** `programs.nixvim.build.package`'s wrapper has **no `-u`**, so running `$OUT/bin/nvim` loads the caller's `~/.config/nvim` (the dev host's real config), *not* the built config — silently. To exercise the built config, launch with `-u "$(nix build --no-link --print-out-paths .#…programs.nixvim.build.initFile)"` and a scratch `HOME`/`XDG_CONFIG_HOME`. `conceallevel` is window-local: set it with `opt_local`/`vim.wo`, never `vim.bo[buf]` (which errors).
