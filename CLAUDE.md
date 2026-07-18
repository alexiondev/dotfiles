# dotfiles-nixos

One flake that builds every machine the user owns.
The domain model (Host, Module, Skeleton, Auto-loader, Enable convention, overlays) lives in `.claude/CONTEXT.md`; the current deliverable's spec is `.claude/spec/laptop-mvi.md`.

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
