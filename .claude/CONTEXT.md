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

**Namespace convention**:
The rule that a Module's option path mirrors its directory path under `modules/`, so a file's location is its namespace.
A file whose name matches its enclosing directory is that directory's index node, declaring the directory's own segment rather than a doubled one.
A directory with no such file is a pure namespace prefix that carries no aggregate enable.
_Avoid_: option tree, module path, config key

**admin identity**:
The age identity held only in the operator's password manager, never committed, that is a recipient of every secrets file.
It is the recovery path for any wiped machine and the credential that authorizes registering a new host.
_Avoid_: master key, admin key, root key

**host identity**:
The dedicated age key on one machine's encrypted root, generated there and never transmitted, that decrypts that machine's own secrets and the shared file.
Deliberately distinct from the machine's SSH host key.
_Avoid_: machine key, node key, host key

**secrets file**:
One sops-encrypted file in the repo, encrypted to the admin identity plus whichever hosts may read it. Either shared across every host or specific to one.
_Avoid_: vault, secret store, keyring

**unstable overlay**:
The overlay exposing `nixpkgs-unstable` packages as `unstable.<name>`, used to pull an individual package fresher than the `nixos-unstable` base.
_Avoid_: bleeding-edge, latest

**stable overlay**:
The overlay exposing the latest stable release (`nixos-26.05`) as `stable.<name>`, used to pin an individual package to the rock-solid release from the `nixos-unstable` base.
_Avoid_: LTS, release channel
