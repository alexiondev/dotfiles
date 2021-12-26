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
    inherit (mylib) loadHosts loadModules;
    mylib = import ./lib.nix { inherit pkgs inputs; lib = nixpkgs.lib; };

    pkgs = import nixpkgs { system = "x86_64-linux"; };
  in {
    inherit mylib;
    
    nixosModules =  loadModules ./modules; 
    nixosConfigurations = loadHosts ./hosts {};
  };
}