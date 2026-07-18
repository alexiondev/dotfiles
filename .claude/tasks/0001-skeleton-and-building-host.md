---
spec: laptop-mvi
---

## What to build

Stand up the `Skeleton` and a minimal `neogaia` `Host` that evaluates and whose system toplevel builds — the walking skeleton every later slice extends and re-verifies against.

The `Skeleton` is a hand-rolled flake (no flake-parts): `nixos-unstable` base channel, an `unstable overlay` exposing `nixpkgs-unstable` as `unstable.<name>`, a `stable overlay` exposing `nixos-26.05` as `stable.<name>`, and chaotic-nyx wired as an input with its overlay and binary cache.
The helper lib is trimmed to three pieces: the `Auto-loader` (recursively discovers and imports every `Module` under `modules/` and every `Host` under `hosts/` with no null-placeholder traversal hack), the host-builder, and the script-from-file helper.
`with lib.my` is not used — dependencies are `inherit`ed explicitly.
The `Enable convention` uses the stdlib enable-option helper; every `Module` is imported unconditionally and guards its body with `mkIf config.modules.<path>.enable`.
home-manager is sourced from `nix-community` (master, nixpkgs followed) and integrated as a NixOS module with global packages and user packages.
The `user` is an explicit option defaulting to `alexion` (no impure environment lookup), placed in `wheel`, driving the system user and the home-manager user in lockstep.
The `neogaia` `Host` carries only enough (placeholder `hardware-configuration.nix`, filesystems/bootloader stubs, `stateVersion`) to make `nixosConfigurations.neogaia.config.system.build.toplevel` evaluate and build; real disk/kernel/networking arrive in later slices.

Design the per-`Host` layout so disk layout, kernel, and channel are all per-`Host` concerns from the start (story 20), so the desktop and servers extend this foundation without restructuring.

## Acceptance criteria

- [x] `nix flake check` succeeds and the flake exposes `nixosConfigurations.neogaia`.
- [x] `nixosConfigurations.neogaia.config.system.build.toplevel` builds.
- [x] Adding a new `.nix` file under `modules/` is auto-discovered and imported without editing any `imports` list, and stays inert until its `enable` flag is set.
- [x] All three overlays resolve: `unstable.<pkg>`, `stable.<pkg>`, and a chaotic-nyx package are each reachable in a `Host`.
- [x] home-manager builds as part of the same `nixos-rebuild switch` toplevel (system + user environment atomic).
- [x] The `user` option defaults to `alexion`, has no impure environment lookup, places the user in `wheel`, and drives both the system and home-manager user.
- [x] The old `nixosModules` flake output and the `with lib.my` idiom are absent.

## Implementation Notes

- **Verification.** `nix flake check` builds `checks.x86_64-linux.neogaia` = the Host toplevel (the spec's primary seam). Overlays confirmed via `nix eval` of `pkgs.unstable.hello` (2.12.3), `pkgs.stable.hello` (2.12.1), and `pkgs.linuxPackages_cachyos.kernel` (7.1.3, from chaotic). Auto-loader inertness confirmed both ways: the reference `modules/example.nix` is off by default, and `extendModules` with `modules.example.enable = true` activates its body.
- **chaotic binary cache.** Wired via `inputs.chaotic.nixosModules.default`, which puts both the `nyx-cache.chaotic.cx` substituter and its trusted public key into the built config (verified by evaluating `config.nix.settings.substituters`/`trusted-public-keys`). chaotic deliberately does **not** follow our nixpkgs, so the cache stays usable. Making the substituter/key explicit is task 0003's concern; here it is inherited from the module.
- **Shared base lives in `system/`.** The Skeleton's shared base config (overlays, `user`, flakes, home-manager wiring) is a `system/` module always imported by the host-builder, kept separate from the auto-loaded feature `Module`s under `modules/` so the base is never gated by an `enable` flag.
- **`modules/example.nix` kept intentionally.** It is the Auto-loader / Enable-convention reference every real Module copies; remove it once a real Module supersedes its teaching value.
- **`scriptFromFile` present but unused.** The task mandates the helper lib carry it ("the script-from-file helper"); its first caller lands with a later Module.
- **Home-manager base user only.** The base sets `home.username`/`homeDirectory`/`stateVersion` for the `user`; `extraSpecialArgs` passes both `inputs` and `my` (the flake lib) so upcoming HM Modules (fish/tmux/nvim) can reach `scriptFromFile`.
- **Deviations from plan.** Added an `options.user.description` (GECOS) alongside `user.name` — small and expected for a real account. Baseline `git` + global `allowUnfree` are set in the base (git is required for flakes; unfree is needed by chaotic/home-manager and later Claude Code). Placeholder `fileSystems`/bootloader and `hardware-configuration.nix` in `neogaia` are stubs that task 0002 (disko) replaces.
