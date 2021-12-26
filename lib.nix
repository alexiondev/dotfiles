# lib.nix -- helper functions for my dotfiles
#
# Author:   Alexion Ramos
# URL:      https://github.com/alexiondev/dotfiles
# LICENSE:  MIT
#
# A collection of helper functions used throughout the dotfiles.

{ inputs, lib, pkgs, ...} : 
let
  sys = "x86_64-linux";
in rec {
  # Recursively loads a path, importing any folders with a default.nix or any .nix files
  # loadDir :: Path -> (String -> Any -> { name = String; value = String; }) -> AttrSet
  loadDir = dir: fn:
    let
      f = n: v:
        let path = "${toString dir}/${n}"; in

        if v == "directory" && builtins.pathExists "${path}/default.nix" 
          then lib.nameValuePair n (fn path) 
        else if v == "directory"
          then lib.nameValuePair n (loadDir path fn)
        else if v == "regular" && n != "default.nix" && lib.hasSuffix ".nix" n
          then lib.nameValuePair (lib.removeSuffix ".nix" n) (fn path)
        else
          lib.nameValuePair "" null;
    in lib.mapAttrs' f (builtins.readDir dir);
  
  # loadModules :: Path -> nixosModules
  loadModules = dir:
    loadDir dir import;
  
  # Creates a nixosSystem configuration from the path.
  # mkHost :: Path -> AttrSet -> nixosSystem
  mkHost = path: args@{system ? sys, ...}:
    lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs lib system; };
      modules = [
        {
          nixpkgs.pkgs = pkgs;
          networking.hostName = lib.mkDefault (baseNameOf path);
        }
        (import ./common.nix) # Common config for all NixOS systems
        (import path)
      ];
    };
  
  # loadHosts :: Path -> AttrSet -> nixosConfigurations
  loadHosts = dir: args:
    loadDir dir (path: mkHost path args);
}