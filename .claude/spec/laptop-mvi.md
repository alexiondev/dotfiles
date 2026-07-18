## Problem Statement

I'm returning to NixOS after ~2 years away, and I want to start by moving my laptop (`neogaia`, a Dell XPS 13 9380 currently running CachyOS) onto it. My old config still exists but is stale and written in a style I no longer want to copy verbatim. Eventually this same config has to grow to cover my desktop and three servers, so whatever I build for the laptop has to be a clean, scalable foundation — not a throwaway.

Reimaging the laptop is destructive and I only get one machine, so I need a tightly-scoped, well-understood **minimum viable install (MVI)**: the smallest config that boots the laptop into a usable state I can then iterate on live, without risking a half-defined system that strands me at a dead console.

## Solution

Rebuild the `Skeleton` and a single `neogaia` `Host` to the point where the laptop:

- boots from an encrypted disk (LUKS + btrfs + zram),
- comes up on wifi,
- lets me log into a console as my user and run `nixos-rebuild switch`,
- and already carries my core terminal tooling (fish, tmux, nvim, Claude Code).

Everything graphical and everything multi-host is deliberately left for later iterative passes, which are safe because a mistake then is "edit and rebuild," not "reimage." The MVI is the one step that must be right *before* reimaging; the rest is reversible.

The install itself is done from the NixOS live ISO by cloning the repo from my Gitea and running a single `disko-install` against the `neogaia` `Host`, then setting a bootstrap password by hand.

## User Stories

1. As the operator, I want the `Skeleton` rewritten around my old scalable ideas (the `Auto-loader`, the `Enable convention`, per-`Host` layout), so that the config stays legible and shareable across all five future machines without me copying stale code.
2. As the operator, I want the flake hand-rolled and cleaned up (no framework layer), so that the whole plumbing stays readable in one place for a config that only targets a handful of `x86_64-linux` machines.
3. As the operator, I want every `Module` auto-discovered and imported but inert until a `Host` sets its `enable` flag, so that each `Host` reads as a checklist of features.
4. As the operator, I want a `nixos-unstable` base with an `unstable overlay` and a `stable overlay`, so that I can run rolling by default but reach up to bleeding-edge or down to rock-solid on a per-package basis.
5. As the operator, I want home-manager integrated as a NixOS module with global packages, so that one `nixos-rebuild switch` builds both the system and my user environment atomically.
6. As the operator, I want my user modelled as an explicit option defaulting to `alexion` (no impure environment lookup), so that the config is reproducible and honest about who the user is.
7. As the operator, I want the laptop's disk declared with `disko` as encrypted btrfs plus zram swap, so that the install is reproducible and the laptop is encrypted at rest.
8. As the operator, I want the system to prompt for the LUKS passphrase at boot via systemd-boot and the initrd, so that the encrypted disk unlocks on a normal boot.
9. As the operator, I want the CachyOS kernel from chaotic-nyx with the chaotic binary cache wired in from the first build, so that I get the performance/feel I'm used to without compiling the kernel from source.
10. As the operator, I want Intel microcode and the redistributable firmware for the QCA6174 wifi included, so that the laptop's hardware works out of the box.
11. As the operator, I want NetworkManager enabled, so that I can join wifi easily from the console.
12. As the operator, I want an SSH daemon running, so that I can drive the rest of the setup remotely if the console is inconvenient.
13. As the operator, I want my user in `wheel` with a manually-set bootstrap password, so that I can log in and use sudo on first boot without committing any secret to a public repo.
14. As the operator, I want fish as my default login shell, configured natively via home-manager with my `cachyos-config.fish` translated (greeting, bat-manpager, `done` and bang-bang plugins, helper functions, eza/nav aliases) and all Arch/pacman-specific parts dropped or replaced with NixOS equivalents, so that my shell feels like home but is correct for NixOS.
15. As the operator, I want tmux configured natively via home-manager using my exact existing `tmux.conf` text, so that my terminal multiplexer is identical to today with no plugin manager needed.
16. As the operator, I want my nvim config brought in verbatim (lazy.nvim managing its own plugins) via a writable out-of-store symlink, with `git`/`gcc`/`ripgrep`/`fd` provided by Nix, so that my editor is identical to today and lazy.nvim can still update and write its lockfile.
17. As the operator, I want Claude Code installed declaratively and authenticatable without a browser on the laptop, so that I can use it over the console/SSH via the paste-code flow or an API key.
18. As the operator, I want timezone `America/New_York`, locale `en_GB.UTF-8`, and console keymap `us` set, so that the base system matches my locale preferences.
19. As the operator, I want to install by cloning the repo from my Gitea onto the live ISO and running `disko-install` against `neogaia`, so that I avoid self-signed-TLS/auth problems with flake fetching during install.
20. As the operator, I want the `Skeleton` designed so that per-`Host` disk layouts, per-`Host` kernels, and preserved ZFS pools are all expressible, so that the same foundation extends to the desktop and the three servers later without restructuring.

## Implementation Decisions

**Skeleton**
- Hand-rolled flake, rewritten and trimmed; no flake-parts.
- `Auto-loader` rewritten: recursively discovers and imports every `Module` under the modules tree without the old null-placeholder traversal hack; a single discovery helper feeds the `Host` imports. The old `nixosModules` flake output is dropped.
- Helper lib trimmed to the `Auto-loader`, the host-builder, and the script-from-file helper. `with lib.my` replaced by explicit `inherit`s throughout. `enable` flags use the stdlib enable-option helper rather than bespoke sugar.
- `nixos-unstable` as the base channel. An `unstable overlay` exposes `nixpkgs-unstable` packages; a `stable overlay` exposes the latest stable release (`nixos-25.05`). chaotic-nyx added as an input with its overlay and binary cache from the start.
- home-manager sourced from `nix-community`, tracking master with nixpkgs followed, integrated as a NixOS module with global packages and user packages.
- User modelled as an explicit option defaulting to `alexion`, in `wheel`, driving the system user and the home-manager user in lockstep.

**neogaia Host**
- Disk declared via `disko`: LUKS-encrypted btrfs with subvolumes plus zram swap. systemd-boot on an EFI system partition; initrd LUKS unlock.
- CachyOS kernel selected via a small per-`Host` kernel mechanism; chaotic substituter and trusted key in the Nix settings.
- Intel microcode; redistributable firmware enabled for the QCA6174 wifi. NetworkManager for networking. A zram toggle `Module` enabled here.
- SSH daemon enabled. Baseline CLI (git, editor, flakes) present. Claude Code installed declaratively.
- fish `Module`: native home-manager configuration; translated aliases/functions/plugins/init; set as the default login shell. tmux `Module`: native home-manager, exact existing config text inlined. nvim `Module`: verbatim config placed as a writable out-of-store symlink with runtime dependencies provided by Nix.
- Locale, timezone, and keymap set to the detected values.

**Install flow**
- Repo pushed to Gitea first. From the NixOS live ISO: join wifi, clone the repo locally, run `disko-install` against the `neogaia` `Host` with the chaotic substituter passed to the install-time daemon, set bootstrap passwords via `nixos-enter`, reboot.

**Secrets (design only in MVI)**
- Per ADR 0001, secrets use `sops-nix` with age keys derived from each `Host`'s SSH host key. The MVI does not wire any secret, because a `Host`'s age key does not exist until its first install generates the SSH host key. The bootstrap password is set by hand and never committed; moving passwords to a `hashedPasswordFile` backed by a sops secret is the first post-boot task, out of scope here.

## Testing Decisions

- A good test here asserts externally-observable evaluation/build success of the whole `Host`, not the internals of any individual `Module`.
- **Primary seam (required):** the `neogaia` `Host` evaluates and its system toplevel builds. Building the toplevel drives the entire `Skeleton` — the `Auto-loader` discovering every `Module`, all three overlays resolving, home-manager integration, and every enabled module's config merging without conflict — plus the `disko` layout, which builds from the same tree. Nearly all config-authoring errors surface at this seam short of booting real hardware.
- No unit-level tests of individual modules; the config-merge model makes the whole-`Host` build the meaningful unit, and it is the highest available seam.
- Prior art: none in this repo yet (it starts empty); this build-the-toplevel check is the pattern to reuse for every future `Host`.
- The genuine end-to-end confirmation is the real reimage, which is manual and irreversible by nature and is not automated.

## Out of Scope

- Any graphical environment: Wayland-vs-i3 choice, greeter/display manager, theming (Nord via Stylix or otherwise), fonts, terminal emulator, browser, general desktop apps, gaming (Steam/Lutris/proton-cachyos), emulation.
- Full `sops-nix` wiring and moving passwords off the bootstrap value (immediate post-boot follow-up, but not MVI).
- Migrating nvim to a native home-manager configuration with Nix-managed plugins.
- chaotic-nyx packages beyond the kernel (`mesa-git`, `proton-cachyos`, `scx` schedulers).
- Flatpak strategy (`nix-flatpak` vs dropping the old imperative helper).
- The desktop `Host` (`zeus`), including Nvidia.
- The three servers: deployment model, service migration (plex/arr/kavita/nfs/torrent-through-protonvpn), ZFS wiring and pool import, backups/monitoring, and per-server kernel/channel pinning.
- VM-based CI (`nixosTest` boot assertions) — explicitly a future addition, not part of this deliverable.

## Further Notes

- **Bootstrap ordering:** the flake must exist on Gitea before the install can consume it, and the manual password step keeps the public repo free of any secret while still yielding a login on first boot.
- **Gitea is a bootstrap dependency:** every NixOS install pulls the config from self-hosted Gitea, so the Gitea host must stay reachable during any install — relevant when sequencing the servers so the migration never locks the operator out of their own configs.
- **chaotic cache at install time:** the install-time Nix daemon on the live ISO must have the chaotic substituter configured, or it compiles the CachyOS kernel from source on the USB stick.
- **Extends to future Hosts by construction:** disk layout, kernel, and channel are all per-`Host` concerns in the `Skeleton`, and existing ZFS pools are preserved by import rather than declared through `disko`. This is what lets the desktop and the three servers join later without reworking the foundation.
- **Theme target is Nord** (the current CachyOS setup is Nord across terminal, tmux, and nvim), superseding the old repo's Dracula — relevant when the theming branch is grilled.
