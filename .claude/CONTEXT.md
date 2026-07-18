# NixOS Dotfiles

A single flake that builds every machine the user owns — laptop, desktop, and three servers — from one shared, modular configuration.

## Language

**Host**:
One physical machine the flake builds a NixOS configuration for. Each Host has a directory under `hosts/` holding its machine-specific `hardware-configuration.nix` and its choice of enabled Modules.
_Avoid_: machine, node, system, box

**Module**:
A single `.nix` feature file under `modules/` that declares an `enable` option and the configuration it turns on. Every Module is always imported but stays inert until a Host enables it.
_Avoid_: component, package, plugin

**Skeleton**:
The flake's plumbing — the Auto-loader, the helper lib, the flake inputs/overlays, and the shared base config — as distinct from the Modules that sit on top of it.
_Avoid_: framework, core, base, scaffolding

**Auto-loader**:
The lib code that recursively discovers and imports every Module under `modules/` (and every Host under `hosts/`) so new files wire themselves in without manual `imports` edits.
_Avoid_: loader, importer, scanner

**Enable convention**:
The rule that every Module is imported unconditionally and guards its own body with `mkIf config.modules.<path>.enable`, so a Host reads as a checklist of `enable = true` flags.
_Avoid_: feature flag, toggle, opt-in

**unstable overlay**:
The overlay exposing `nixpkgs-unstable` packages as `unstable.<name>`, used to pull an individual package fresher than the `nixos-unstable` base.
_Avoid_: bleeding-edge, latest

**stable overlay**:
The overlay exposing the latest stable release (`nixos-25.05`) as `stable.<name>`, used to pin an individual package to the rock-solid release from the `nixos-unstable` base.
_Avoid_: LTS, release channel
