{
  description = "Alexion's NixOS configuration — one flake for every Host";

  inputs = {
    # Base channel: nixos-unstable (rolling, but gated by the NixOS test suite).
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Fresher-than-base packages, reachable per-package as `unstable.<name>`.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Latest stable release, reachable per-package as `stable.<name>`.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # CachyOS kernel + binary cache. Deliberately NOT following our nixpkgs, so the
    # chaotic cache stays usable and the kernel is fetched rather than compiled.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      my = import ./lib { inherit lib inputs self; };
    in
    {
      # The trimmed helper lib: the Auto-loader, the host-builder, the script-from-file helper.
      lib = my;

      # Every Host under hosts/ is auto-discovered and built.
      nixosConfigurations = my.mkHosts (self + "/hosts");

      # `nix flake check` builds each Host's toplevel — the primary test seam.
      checks.x86_64-linux = lib.mapAttrs (
        _name: host: host.config.system.build.toplevel
      ) self.nixosConfigurations;
    };
}
