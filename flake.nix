# flake.nix -- the core of my dotfiles
#
# Author:   Alexion Ramos
# URL:      https://github.com/alexiondev/dotfiles
# LICENSE:  MIT
#
# This is the entry point to the dotfiles. Start here!

{
  description = "The best (read: worst) dotfiles you'll ever (read: never) need.";

  inputs = {
    nixpkgs.url       = "nixpkgs/nixos-unstable";
    unstable.url      = "nixpkgs/nixpkgs-unstable";

    home-manager.url  = "github:rycee/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ { self, nixpkgs, unstable, ...}:
  let
    inherit (lib.my) loadHosts loadModules;

    pkgs = import nixpkgs { system = "x86_64-linux"; };

    lib = nixpkgs.lib.extend
      (self: super: {my = import ./lib.nix { inherit pkgs inputs; lib = self; };});
  in {
    lib = lib;
    
    nixosModules = loadModules ./modules; 
    nixosConfigurations = loadHosts ./hosts {};
  };
}