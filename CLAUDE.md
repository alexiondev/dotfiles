# dotfiles-nixos

One flake that builds every machine the user owns.
The domain model (Host, Module, Skeleton, Auto-loader, Enable convention, overlays) lives in `.claude/CONTEXT.md`; the current deliverable's spec is `.claude/spec/laptop-mvi.md`.

## Conventions

- In-file comments describe only the current content and behaviour of the file they sit in.
  Do not write comments about history ("used to be X", "now moved here"), about how a value is consumed in other files, or that justify the choice against alternatives.
  Never reference agent-facing state (anything under `.claude/` or `CLAUDE.md`) from a code comment: that state is not part of understanding the code.
  A reader looking at only that file should find every comment accurate and self-contained.
- Comments posted to Gitea (pull requests, issues, reviews) go out under the operator's account, so sign every one to make clear the author is the agent, not the operator.
  End the comment with a `— Claude` sign-off.
  (A dedicated bot account may replace this later; until then, the sign-off is the only marker.)

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
