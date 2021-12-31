# flake.nix -- the core of my dotfiles
#
# Author:   Alexion Ramos
# URL:      https://github.com/alexiondev/dotfiles
# License:  MIT
#
# This is the entry point to the dotfiles, start from here!

{
  description = "The best (read: worst) dotfiles you'll ever (read: never) need.";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:rycee/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ { self, nixpkgs, nixpkgs-unstable, ... }:
  let inherit (lib.my) loadHosts loadModules;
      lib = nixpkgs.lib.extend
        (self: super: {my = import ./lib.nix { inherit pkgs inputs; lib = self; };});
      
      mkPkgs = pkgs: extraOverlays: import pkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = extraOverlays;
      };

      pkgs  = mkPkgs nixpkgs [ self.overlay ];
      pkgs' = mkPkgs nixpkgs-unstable [];
  in {
    lib = lib;

    overlay = final: prev: {
      unstable = pkgs';
    };

    nixosModules = loadModules ./modules;
    nixosConfigurations = loadHosts ./hosts {};
  };
}