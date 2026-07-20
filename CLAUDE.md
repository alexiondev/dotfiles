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

- This repo is developed on `neogaia`, which now runs the NixOS it builds.
  Flakes and the chaotic substituter come from this flake's own `nix.settings`, so no `NIX_CONFIG` export or per-command `--extra-experimental-features` is needed, and building a toplevel with `boot.kernelPackages = linuxPackages_cachyos` fetches the kernel from `nyx-cache` rather than compiling it.
  Both were true only while the machine still ran CachyOS against a distro Nix daemon.
- The substituters a `nix build` fetches from are the **daemon's** (`/etc/nix/nix.conf`), *not* the `nix.settings` of the config being built — those only govern the built system.
  The two coincide here because the dev host runs this flake; they diverge on any machine that does not.
- Git identity is not declared in the flake — there is no `programs.git` — so it must be set by hand before the first commit on a fresh machine.
  The July 2026 reimage confirmed this: it wiped the hand-written `~/.gitconfig`, and the next commit failed with `Author identity unknown`, auto-detecting `alexion@neogaia.(none)`.
  It now lives in this checkout's `.git/config`, which reaches no other machine and does not survive the next reimage either; history uses `alexion <contact@alexion.dev>`.
- The primary build/verify seam for any Host is `nix flake check`, which builds `checks.x86_64-linux.<host>` (the system toplevel); cheap targeted checks use `nix eval .#nixosConfigurations.<host>.config...`.
- A flake only sees **git-tracked** files, so a new file that has not been `git add`ed is invisible to evaluation even though it exists on disk.
  The failure names the path and reads as if the file were missing: `error: Path 'secrets/shared.yaml' does not exist in Git repository`.
  Staging is enough; the file need not be committed.
- chaotic-nyx must **not** follow our `nixpkgs`, and its packages are built against chaotic's own pinned nixpkgs (its overlay defaults to `onTopOf = "flake-nixpkgs"`, the cache-friendly path).
  That is what lets the `nyx-cache.chaotic.cx` binary cache hit instead of compiling the CachyOS kernel from source; the tradeoff is that chaotic packages do not see our `unstable`/`stable` overlays.
- The remote is self-hosted Gitea (`git.alexion.dev`), and the intended CLI is `gitea-axi` rather than `tea`.
  `gitea-axi` resolves the repository from the `origin` remote and takes credentials from the `axi` tea login, so both are implicit inside a checkout.
  **None of it is installed on the NixOS build.** No `gitea-axi`, no `tea`, no `gh`, no tea login under `~/.config/tea`, and no `GITEA_*` environment — the flake names `gitea-axi` only as the claude-code module's `SessionStart` hook command and never packages it, so that hook invokes a binary that is not on `PATH`.
  Pull requests therefore cannot be opened from this machine until a module provides the tool and its credentials; branches can only be pushed.
  The earlier claim that `tea` remains installed described the machine while it still ran CachyOS with these tools installed by hand.
- `~/.claude/skills` is generated by home-manager with `recursive = true`, so the directories are real and writable but every leaf file is a read-only symlink into the store.
  Editing a skill in place fails; its source is `modules/claude-code/skills/<name>/` here, applied by a rebuild.
  Creating a new file under `~/.claude/skills/` succeeds silently and is the trap — it stays outside the repo and reaches no other machine.
  Copying out of that tree needs `cp -rL` plus `chmod -R u+w`: a plain `cp -r` copies the symlinks, putting store paths into the destination, and dereferenced files keep the store's read-only mode.
- `home-manager.users.<user>.home.file` is keyed by **absolute** path, not by a path relative to the home directory.
  Evaluating `home.file.".claude/CLAUDE.md"` fails with "does not provide attribute"; the working key is `home.file."/home/alexion/.claude/CLAUDE.md"`.
  List the real keys with `nix eval --json .#nixosConfigurations.<host>.config.home-manager.users.<user>.home.file --apply builtins.attrNames` rather than guessing one.
  A key's `.source` is the input file, whose store path differs from the deployed symlink's target (home-manager copies it to a `hm_`-prefixed path) even though the contents match.
- nixpkgs `vimPlugins.nord-nvim` is `shaunsingh/nord.nvim` (no `require("nord").setup()`); the config wants `gbprod/nord.nvim`, which is packaged as `vimPlugins.gbprod-nord`.
- nixpkgs `vimPlugins.nvim-treesitter` tracks the rewritten `main` branch: there is no `require("nvim-treesitter.configs").setup{ensure_installed,highlight,indent}`. Under nixvim, use `plugins.treesitter` with `highlight.enable`/`indent.enable` and `grammarPackages = with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [ ... ]` — the module's own `package.builtGrammars`, **not** `pkgs.vimPlugins.nvim-treesitter.*` (whose query files can mismatch). The module targets the main branch and enables features via neovim-native APIs (`vim.treesitter.start()`, `require'nvim-treesitter'.indentexpr()`).
- Neovim is configured via **nixvim** (flake input `nixvim`, consumed as `inputs.nixvim.homeModules.nixvim` added to `home-manager.sharedModules`, config under `home-manager.users.<user>.programs.nixvim`). `nixvim.inputs.nixpkgs.follows = "nixpkgs"` is set; nixvim then emits a benign eval warning that its pinned nixpkgs differs from the followed one — builds and runs fine, do not "fix" it by dropping the follows.
- To reference the nixvim-built package's own attrs (e.g. treesitter `builtGrammars`) inside our NixOS module, give `home-manager.users.<user>` the module-function form (`hm: { programs.nixvim = { ... hm.config.programs.nixvim... }; }`), since the outer `config` is the NixOS config, not the home-manager one.
- The agent's Bash sandbox blocks `sudo` and swallows it into a bare exit 1 with **no stderr**, which looks identical to the command itself failing.
  Re-run with the sandbox disabled to see the real error (`sudo: a password is required`) before diagnosing anything else.
  Separately, `nixos-generate-config --show-hardware-config` needs root on this machine even just to print: unprivileged it dies at `Failed to retrieve subvolume info for /`, because the root filesystem is btrfs.
- Sudo's credential cache is keyed per user rather than per terminal (`timestamp_type=global`, 60-minute window, declared by the claude-code module), so an authentication made in one terminal counts for commands the agent runs.
  Warming it with `sudo -v` through the agent's own shell — including the `!` prefix — never works: that shell has no controlling terminal, and sudo reports `a terminal is required to read the password`.
  It has to be a separate terminal.
  A `PreToolUse` hook refuses privileged commands while the cache is cold, so a cold cache announces itself instead of stalling; a failure *without* that message is the sandbox, not the cache.
- `home-manager.users.<user>` cannot be assigned twice at the same level in one module: `home-manager.users.${user}.home.packages` alongside `home-manager.users.${user}.programs.x` fails with `error: dynamic attribute 'alexion' already defined`.
  The interpolated key makes it a dynamic attribute, which nix will not merge the way it merges static paths.
  Nest both under a single `home-manager.users.${user} = { ... }`.
- **Verifying a nixvim change headless:** `programs.nixvim.build.package`'s wrapper has **no `-u`**, so running `$OUT/bin/nvim` loads the caller's `~/.config/nvim` (the dev host's real config), *not* the built config — silently. To exercise the built config, launch with `-u "$(nix build --no-link --print-out-paths .#…programs.nixvim.build.initFile)"` and a scratch `HOME`/`XDG_CONFIG_HOME`. `conceallevel` is window-local: set it with `opt_local`/`vim.wo`, never `vim.bo[buf]` (which errors).
