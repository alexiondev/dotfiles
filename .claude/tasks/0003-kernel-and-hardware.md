---
spec: laptop-mvi
blocked-by: 0001-skeleton-and-building-host
---

## What to build

Give `neogaia` the kernel and hardware enablement it needs to run well on the Dell XPS 13 9380: the CachyOS kernel pulled as a binary from chaotic-nyx (not compiled from source), Intel microcode, and the redistributable firmware for the QCA6174 wifi. Add a zram toggle `Module` and enable it here.

The kernel is selected through a small per-`Host` kernel mechanism so other `Host`s can choose different kernels. The chaotic substituter and its trusted public key are added to the Nix settings so the kernel is fetched from the binary cache from the first build.

## Acceptance criteria

- [x] `neogaia` runs the CachyOS kernel selected via a per-`Host` kernel mechanism, sourced from chaotic-nyx.
- [x] The chaotic substituter and trusted public key are in the Nix settings, so the kernel is fetched from cache rather than compiled.
- [x] Intel microcode is enabled.
- [x] Redistributable firmware is enabled so the QCA6174 wifi hardware is available.
- [-] A zram toggle `Module` exists (following the `Enable convention`) and is enabled on `neogaia`. — Module dropped in PR review; zram is enabled inline on `neogaia` instead (see notes).
- [x] The `neogaia` toplevel still builds with all of the above.

## Implementation Notes

- **Per-`Host` kernel mechanism = native `boot.kernelPackages`.** neogaia sets `boot.kernelPackages = pkgs.linuxPackages_cachyos` directly in its Host directory (`hosts/neogaia/default.nix`). No custom wrapper option was added: `boot.kernelPackages` is already a per-`Host` setting, so other `Host`s pick their own kernel the same way. A string→package wrapper would have been premature abstraction with one `Host` and one kernel, so it was deliberately left out; the "mechanism" is the per-`Host` placement of the native option.
- **Substituter/key live in the shared base, via the `extra-` options.** They were added to `system/default.nix` (shared by every `Host`), not just neogaia, because the chaotic module is wired for all `Host`s and the cache is general plumbing. `nix.settings.extra-substituters` / `extra-trusted-public-keys` are used rather than the replacing `substituters` / `trusted-public-keys`, so `cache.nixos.org` (and any other substituter) is only appended to, never dropped. chaotic's own module also provides these entries; the explicit declaration is belt-and-suspenders and keeps the built system's cache config visible and independent of that module.
- **Dev-host build needed a daemon-level cache.** Building the toplevel here first compiled the CachyOS kernel (and rustc bootstrap) from source, because the build daemon's `/etc/nix/nix.conf` had no `nyx-cache` substituter — the built system's `nix.settings` do not govern the daemon doing the build, and the dev user is a non-trusted client that cannot add substituters from the CLI. Adding `extra-substituters`/`extra-trusted-public-keys` for `nyx-cache` to `/etc/nix/nix.conf` (sudo) and restarting `nix-daemon` fixed it; the build then fetched the kernel (7.1.3) from the cache. Recorded as a gotcha in `CLAUDE.md`.
- **zram is enabled inline, not as a `Module` (criterion 5 dropped).** The task asked for a zram toggle `Module`, and one was built first (`modules/zram.nix`), but PR review rejected it as a single-line abstraction that wraps the native `zramSwap.enable` toggle without adding anything. It was removed, and `neogaia` sets `zramSwap.enable = true` directly, as it did before task 0003. The `Enable convention` reference remains `modules/example.nix`; real feature `Module`s arrive with fish/tmux/nvim/Claude Code in later tasks.
