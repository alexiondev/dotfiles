{
  description = "Alexion's NixOS configuration — one flake for every host";

  inputs = {
    # Base channel.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Fresher packages, reachable per-package as `unstable.<name>`.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Latest stable release, reachable per-package as `stable.<name>`.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Follows our nixpkgs so its plugins build against the same package set.
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning; each host declares its own layout.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Upstream per-machine hardware profiles; each host imports its own.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Decrypts committed secrets at activation, from an age identity on the host.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # CachyOS kernel and binary cache. Pins its own nixpkgs so its cache stays
    # usable and the kernel is fetched from it.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      my = import ./lib { inherit lib inputs self; };
    in
    {
      # Helper functions for discovering and building hosts.
      lib = my;

      # Every host under hosts/ is discovered and built.
      nixosConfigurations = my.mkHosts (self + "/hosts");

      # `nix flake check` builds each host's toplevel.
      checks.x86_64-linux = lib.mapAttrs (
        _name: host: host.config.system.build.toplevel
      ) self.nixosConfigurations;
    };
}
