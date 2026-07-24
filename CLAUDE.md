# dotfiles-nixos

One flake that builds every machine the user owns.
The domain model (Host, Module, Skeleton, Auto-loader, Enable convention, overlays) lives in `.claude/CONTEXT.md`; the current deliverable's spec is `.claude/spec/laptop-mvi.md`.

## Conventions

- Comments posted to Gitea (pull requests, issues, reviews) go out under the operator's account, so sign every one to make clear the author is the agent, not the operator.
  End the comment with a `— Claude` sign-off.
  (A dedicated bot account may replace this later; until then, the sign-off is the only marker.)
- Commit messages follow Conventional Commits, specified in `docs/conventional-commits.md`.
  Scope is the module or host the change belongs to (`fish`, `nvim`, `neogaia`), omitted for repo-wide changes.
  Keep messages free of Gitea-specific references: this repository is mirrored to GitHub, where issue and pull-request numbers resolve to unrelated things.
- When a graphical application is added, give it a `window-rewrite` icon mapping in `modules/desktop/waybar.nix`.
  Without one its windows fall back to the generic default glyph on the workspace indicator instead of showing a recognisable per-application icon.
  Match on the window class, which `hyprctl clients -j | jq -r '.[].class' | sort -u` lists for the running session.

## Gotchas

- This repo is developed on `neogaia`, which now runs the NixOS it builds.
  Flakes and the chaotic substituter come from this flake's own `nix.settings`, so no `NIX_CONFIG` export or per-command `--extra-experimental-features` is needed, and building a toplevel with `boot.kernelPackages = linuxPackages_cachyos` fetches the kernel from `nyx-cache` rather than compiling it.
  Both were true only while the machine still ran CachyOS against a distro Nix daemon.
- The substituters a `nix build` fetches from are the **daemon's** (`/etc/nix/nix.conf`), *not* the `nix.settings` of the config being built — those only govern the built system.
  The two coincide here because the dev host runs this flake; they diverge on any machine that does not.
- Git identity is declared in the flake by `modules/git.nix`, which writes `alexion <contact@alexion.dev>` — the identity all history uses — on any host enabling `modules.git`.
  Every new host has to enable it, so that a host reads as a full checklist of what it carries.
  It is deployed on `neogaia` and verified: a commit in a repository outside this checkout is authored `alexion <contact@alexion.dev>` with no override.
  Verify it that way rather than from this checkout, whose `.git/config` carries the same identity and would mask a broken module.
  Home-manager writes `~/.config/git/config`, and `~/.gitconfig` is a second global file that git also reads, outranking it on any key set in both.
  `~/.gitconfig` currently holds only a `tea` credential helper and no `user.*`, so it does not shadow the identity, but it is undeclared and will not survive a reimage.
- `git config --global` is a listing and writing filter over `~/.gitconfig` alone, **not** a view of what git resolves.
  With both global files present it prints only `~/.gitconfig`, which reads as proof that `~/.config/git/config` is being ignored entirely.
  It is not: drop `--global` and both files appear, each key resolving to the last file that sets it.
  A `git config --global <key> <value>` write also lands in `~/.gitconfig`, the file that outranks the flake-managed one.
- The primary build/verify seam for any Host is `nix flake check`, which builds `checks.x86_64-linux.<host>` (the system toplevel); cheap targeted checks use `nix eval .#nixosConfigurations.<host>.config...`.
- A flake only sees **git-tracked** files, so a new file that has not been `git add`ed is invisible to evaluation even though it exists on disk.
  The failure names the path and reads as if the file were missing: `error: Path 'secrets/shared.yaml' does not exist in Git repository`.
  Staging is enough; the file need not be committed.
- chaotic-nyx must **not** follow our `nixpkgs`, and its packages are built against chaotic's own pinned nixpkgs (its overlay defaults to `onTopOf = "flake-nixpkgs"`, the cache-friendly path).
  That is what lets the `nyx-cache.chaotic.cx` binary cache hit instead of compiling the CachyOS kernel from source; the tradeoff is that chaotic packages do not see our `unstable`/`stable` overlays.
- The remote is self-hosted Gitea (`git.alexion.dev`), and the forge CLI is `gitea-axi` rather than `tea`.
  `gitea-axi` resolves the repository from the `origin` remote and discovers credentials from a `tea` login whose host matches the remote, so both are implicit inside a checkout.
  It is installed on `neogaia` by `modules.agents.tools.gitea-axi`, and verified: `gitea-axi` run from this checkout renders the `alexion/dotfiles` dashboard authenticated, so the claude-code `SessionStart` hook that runs it now resolves to a real binary rather than a missing one.
  The package wraps the binary so `git` and `tea` are reachable without being on `PATH`, while still preferring the operator's own where present.
  Credentials: `~/.config/tea/config.yml` holds a token-bearing login named `alexion`, which `gitea-axi` uses and which also opens pull requests directly with `nix run nixpkgs#tea -- pr create --login alexion --repo alexion/dotfiles --base main --head <branch> ...`.
  The `--repo` flag is required on that path, since `tea` resolves `origin` only for a login whose SSH host matches.
  The same token reads PR discussion, which `tea` itself does poorly: `tea pr <n> --comments` prints only the body, and `-f comments` returns no comments field at all.
  Use the API instead, taking the token from `.logins[] | select(.name=="alexion") | .token`.
  Review comments are **not** at `/issues/<n>/comments` — that endpoint holds only top-level discussion and is usually empty.
  Inline comments need two calls: `/pulls/<n>/reviews` for the review ids, then `/pulls/<n>/reviews/<id>/comments` for the bodies, whose `path` and `diff_hunk` fields say what each one is attached to.
  A review row with an empty `body` is the normal shape when the operator left only inline comments.
- SSH **host** keys (`ssh_host_<type>_key`, served by the daemon from `/etc/ssh` or a secret) are not user authentication keys (`~/.ssh/id_ed25519`, offered to a remote server).
  The `ssh_host_` prefix is OpenSSH's own name for the former, and the `root@<host>` trailing field in a `.pub` is a free-text comment stamped by `ssh-keygen` at generation time, not a claim about which account uses the key.
  On this machine the two are provably distinct: the daemon presents `SHA256:2ysuBX0+Z6GbdCTujz5JHX6rqnJzIyWhYNrxdhhGwEM`, while pushes to `git.alexion.dev` authenticate with `SHA256:nEhHwtHDnLlsuFxyfp+cETgHUZ8xDMxaPVmYM5vuCkA`.
  Renaming host keys after user keys, or vice versa, is therefore always wrong.
- `~/.claude/skills` is generated by home-manager with `recursive = true`, so the directories are real and writable but every leaf file is a read-only symlink into the store.
  Editing a skill in place fails; its source is `modules/agents/claude-code/skills/<name>/` here, applied by a rebuild.
  Creating a new file under `~/.claude/skills/` succeeds silently and is the trap — it stays outside the repo and reaches no other machine.
  Copying out of that tree needs `cp -rL` plus `chmod -R u+w`: a plain `cp -r` copies the symlinks, putting store paths into the destination, and dereferenced files keep the store's read-only mode.
- `home-manager.users.<user>.home.file` is keyed by whatever path string the **defining module wrote**, absolute or relative, not by one canonical form.
  A module that writes `home.file."/home/alexion/.claude/CLAUDE.md"` is reachable only at that absolute key, while `programs.firefox` writes relative keys such as `home.file.".config/mozilla/firefox/profiles.ini"` reachable only at the relative form.
  The other form fails with "does not provide attribute", so overriding an entry (e.g. setting `.force = true` on it) requires matching the writer's exact key.
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
- An `mkOption` of a list or attribute-set type is **not** mandatory the way a scalar one is.
  Those types carry an `emptyValue`, so an option declared with no `default` and never set evaluates to `[ ]` or `{ }` instead of failing with "option used but not defined".
  A declaration that is genuinely required cannot be expressed by omitting the default — it needs an assertion, or a default chosen so that the silent case is the safe one.
  This bites hardest where the empty value is itself dangerous, such as a list of authorized SSH keys, where it means a machine nobody can reach.
- `home-manager.users.<user>` cannot be assigned twice at the same level in one module: `home-manager.users.${user}.home.packages` alongside `home-manager.users.${user}.programs.x` fails with `error: dynamic attribute 'alexion' already defined`.
  The interpolated key makes it a dynamic attribute, which nix will not merge the way it merges static paths.
  Nest both under a single `home-manager.users.${user} = { ... }`.
- **Verifying a nixvim change headless:** `programs.nixvim.build.package`'s wrapper has **no `-u`**, so running `$OUT/bin/nvim` loads the caller's `~/.config/nvim` (the dev host's real config), *not* the built config — silently. To exercise the built config, launch with `-u "$(nix build --no-link --print-out-paths .#…programs.nixvim.build.initFile)"` and a scratch `HOME`/`XDG_CONFIG_HOME`. `conceallevel` is window-local: set it with `opt_local`/`vim.wo`, never `vim.bo[buf]` (which errors).
- Host GPUs: `neogaia` is Intel and `zeus` (the desktop) is **AMD**.
  `raichu`, a server with no desktop, is the only Nvidia machine.
  `laptop-mvi.md`'s out-of-scope line calls zeus Nvidia, but that is stale and the document is kept historical and unchanged, so do not infer any host's GPU from it.
  The corrected fact lives in ADR 0003 and the `hyprland-desktop` spec.
- The home-manager `wayland.windowManager.hyprland` module defaults `configType` to `"lua"` at `home.stateVersion` >= 26.05, writing `hyprland.lua` through an `hl.*` Lua API instead of the native `hyprland.conf`.
  The Lua backend mangles `$mod`-style variables and INI `bind=` strings into invalid Lua (`hl.$mod("SUPER")`), and does not fail the build, since the config is only text.
  Set `configType = "hyprlang"` to get the native `hyprland.conf` whose variable and bind syntax the usual settings are written in.
  Render the file to check which format is in effect: `nix build --print-out-paths .#nixosConfigurations.<host>.config.home-manager.users.<user>.xdg.configFile.\"hypr/hyprland.conf\".source` (only the enabled `configType`'s key exists).
- An invalid Hyprland dispatcher or config-option name never fails the nix build, since `hyprland.conf` is only text, so it surfaces only when the compositor loads the file at login.
  The build/render check is therefore blind to it, and the real test is a running session (or reading `~/.config/hypr/hyprland.conf` against the running package's own names).
  Two that bit on 0.55.4: the dwindle split actions `togglesplit`, `swapsplit`, and `pseudo` are layout messages reached through the `layoutmsg` dispatcher (`bind = $mod, T, layoutmsg, togglesplit`), not top-level dispatchers, and the old `dwindle:pseudotile` option is gone.
  Confirm names against the pinned package rather than the wiki, whose "latest" drifts from it.
  The config can in fact be checked offline: `Hyprland --verify-config -c <rendered-conf>` parses the file and prints `config ok` or the exact `line N:` error without a running compositor, so a rule change is provable before login rather than only at it.
- Hyprland 0.55.4 uses windowrule v3 syntax, which is not the `windowrule = float, class:^(re)$` form the wiki still shows.
  A flat `windowrule =` entry is a comma-separated list of `field value` tokens, each of which **must** carry a value: matchers take a `match:` prefix and effects are bare, so floating one app is `windowrule = float 1, match:class ^(com\.gabm\.satty)$`.
  The old form fails at load with `invalid field float: missing a value`, because the effect token has no value.
  `windowrulev2` is removed and errors as deprecated.
- A multi-path `git add a b c` aborts entirely and stages **nothing** when any one pathspec matches no file, so a stale path in the list silently drops every other file from the commit.
  This bit here: a path already removed by `git rm` was passed to a later `git add`, which failed with `fatal: pathspec ... did not match any files` and staged none of the real edits beside it, landing a commit that moved files but kept the old option paths.
  Stage in separate `git add` calls, or `git status` the result before committing rather than trusting the add.
- A `nix build` or `nix flake check` on a **dirty** tree evaluates the working-copy content of tracked files, not what is committed, and only warns `Git tree ... is dirty`.
  A green check on a dirty tree therefore proves nothing about the commit.
  To verify a commit, build once on a clean tree (nothing uncommitted), where the absence of the dirty warning confirms the build reflects `HEAD`.
- home-manager's `programs.firefox` declarative `search` with `force = true` does **not** prune Firefox's built-in engines by omission.
  The overwrite writes `search.json.mozlz4` with only the engines listed, but Firefox reconciles its locale's app-provided engines back in for any not present in the file, so Google, Bing, and the rest reappear.
  To actually remove a builtin, list it explicitly with `<engine>.metaData.hidden = true` — an engine entry carrying only `metaData` is treated as a builtin rather than a custom engine.
  Engines are referenced by their current id, which the module maps from the old display names, so the default is `default = "ddg"`, not `"DuckDuckGo"` (the latter only warns and migrates).
  Prove the result by decoding the built file: `mozlz4a -d <search.json.mozlz4>` shows the `_metaData.hidden` flags and `defaultEngineId`.
