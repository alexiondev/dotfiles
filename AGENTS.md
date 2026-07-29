# dotfiles-nixos

One flake that builds every machine the user owns.
The domain model (Host, Module, Skeleton, Auto-loader, Enable convention, overlays) lives in `.agents/CONTEXT.md`.

## Conventions

- Comments posted to Gitea (pull requests, issues, reviews) go out under the operator's account, so sign every one to make clear the author is the agent, not the operator.
  End the comment with a `— Claude` sign-off.
  (A dedicated bot account may replace this later.
  Until then, the sign-off is the only marker.)
- Commit messages follow Conventional Commits, specified in `docs/conventional-commits.md`.
  Scope is the module or host the change belongs to (`fish`, `nvim`, `neogaia`), omitted for repo-wide changes.
  Keep messages free of Gitea-specific references: this repository is mirrored to GitHub, where issue and pull-request numbers resolve to unrelated things.
- When a graphical application is added, give it a `window-rewrite` icon mapping in `modules/desktop/waybar.nix`.
  Without one its windows fall back to the generic default glyph on the workspace indicator instead of showing a recognisable per-application icon.
  Match on the window class, which `hyprctl clients -j | jq -r '.[].class' | sort -u` lists for the running session.

## Gotchas

- This repo pins no Nix formatter, and its committed `.nix` files are not clean under current `nixfmt-rfc-style`.
  Running `nixfmt` across a file reflows untouched code (for example `lib.nix`'s `deriveMac` list and multi-line assertion messages) and injects churn unrelated to the change.
  Format only the lines being written or changed, matching the surrounding style by hand.
- This repo is developed on `neogaia`, which now runs the NixOS it builds.
  Flakes and the chaotic substituter come from this flake's own `nix.settings`, so no `NIX_CONFIG` export or per-command `--extra-experimental-features` is needed, and building a toplevel with `boot.kernelPackages = linuxPackages_cachyos` fetches the kernel from `nyx-cache` rather than compiling it.
  Both were true only while the machine still ran CachyOS against a distro Nix daemon.
- Git identity is declared in the flake by `modules/git.nix`, which writes `alexion <contact@alexion.dev>` — the identity all history uses — on any host enabling `modules.git`.
  Every new host has to enable it, so that a host reads as a full checklist of what it carries.
  It is deployed on `neogaia` and verified: a commit in a repository outside this checkout is authored `alexion <contact@alexion.dev>` with no override.
  Verify it that way rather than from this checkout, whose `.git/config` carries the same identity and would mask a broken module.
  `~/.gitconfig` (a second global file that outranks the flake-managed `~/.config/git/config`) currently holds only a `tea` credential helper and no `user.*`, so it does not shadow the identity, but it is undeclared and will not survive a reimage.
- The primary build/verify seam for any Host is `nix flake check`, which builds `checks.x86_64-linux.<host>` (the system toplevel).
  Cheap targeted checks use `nix eval .#nixosConfigurations.<host>.config...`.
- chaotic-nyx must **not** follow our `nixpkgs`, and its packages are built against chaotic's own pinned nixpkgs (its overlay defaults to `onTopOf = "flake-nixpkgs"`, the cache-friendly path).
  That is what lets the `nyx-cache.chaotic.cx` binary cache hit instead of compiling the CachyOS kernel from source.
  The tradeoff is that chaotic packages do not see our `unstable`/`stable` overlays.
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
- `~/.claude/skills` and `~/.pi/agent/skills` are home-manager-generated (`recursive = true`), so editing a skill in place fails and a new file created there silently escapes the repo.
  Shared global skills come from the `skills` flake through `modules/agents/skills.nix`, applied by a rebuild.
  Claude-specific legacy skills, when kept, live under `modules/agents/claude-code/skills/<name>/`.
- nixpkgs `vimPlugins.nord-nvim` is `shaunsingh/nord.nvim` (no `require("nord").setup()`).
  The config wants `gbprod/nord.nvim`, which is packaged as `vimPlugins.gbprod-nord`.
- `nixos-generate-config --show-hardware-config` needs root on this machine even just to print: unprivileged it dies at `Failed to retrieve subvolume info for /`, because the root filesystem is btrfs.
- This repo's claude-code module sets sudo's credential cache to per-user (`timestamp_type=global`, 60-minute window), so an authentication made in one real terminal counts for the agent's commands.
  A `PreToolUse` hook refuses privileged commands while the cache is cold, so a cold cache announces itself instead of stalling.
  A privileged-command failure *without* that message is the sandbox, not the cache.
- Host GPUs: `neogaia` is Intel, `zeus` (the desktop) is **AMD**, and `raichu` (a headless server) is the only Nvidia machine.
  The corrected fact also lives in ADR 0003.
- This repo's `programs.firefox` `search` (with `force = true`) writes `search.json.mozlz4`.
  Omission alone does not prune a built-in engine, since Firefox reconciles its app-provided engines back in, so remove one by listing it with `<engine>.metaData.hidden = true`.
  Engines are referenced by their current id, so the default is `default = "ddg"`, not `"DuckDuckGo"`.
  Decode the built file with `mozlz4a -d <search.json.mozlz4>` to check the result.
- `home.sessionVariables` do **not** reach the Hyprland session, since UWSM does not source `hm-session-vars.sh`.
  The cursor is therefore set through Hyprland's own `env = KEY,VALUE` in `modules/desktop/hyprland/hyprland.nix`, sourced from `config.stylix.cursor`.
  Bibata ships XCursor format only (no `hyprcursor/` dir), rendered through Hyprland's XCursor fallback, so `XCURSOR_*` and `HYPRCURSOR_*` naming the same theme are both safe.
- `neogaia`, the repo's only host, is a wifi laptop with a btrfs root and no ZFS pools, so it cannot honestly carry `modules.network`, `modules.zfs`, or a networked/pool-mounted guest.
  Enabling networkd takes over its DNS, its CachyOS `zfs-kernel` build is marked broken, and it has no bridge or pool to attach to.
  Verify these against it ad hoc through `nixosConfigurations.neogaia.extendModules` (forcing a ZFS-capable `boot.kernelPackages` for the zfs case) plus `nix eval` of the derived values, never by committing the enablement.
  A committed guest therefore leaves `vlan`, `mounts`, and `secrets` unset, and the standing enablement waits for the first wired server host with real storage.
