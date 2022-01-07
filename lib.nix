# lib.nix -- helper functions for my dotfiles
#
# Author:   Alexion Ramos
# URL:      https:/github.com/alexiondev/dotfiles
# License:  MIT
#
# A collection of helper functions used throughout the dotfiles.

{ inputs, lib, pkgs, ...} :
let sys = "x86_64-linux";
in rec {
  # Maps a function recursively over a directory.
  # mapDir :: Path -> (str -> Any -> Any) -> AttrSet
  mapDir = dir: fn:
    let f = n: v:
      let path = "${toString dir}/${n}"; in

      if v == "directory" && builtins.pathExists "${path}/default.nix"
        then fn n path
      else if v == "directory"
        then fn n (mapDir path fn)
      else if v == "regular" && n != "default.nix" && lib.hasSuffix ".nix" n
        then fn (lib.removeSuffix ".nix" n) path
      else
        fn "" null;
    in lib.mapAttrs' f (builtins.readDir dir);

  # loadModules :: Path -> nixosModules
  loadModules = dir:
    mapDir dir (n: path: lib.nameValuePair n (import path));

  # findModules :: Path -> [Path]
  findModules = dir:
    let dirs = mapDir dir lib.nameValuePair;
        dirs' = lib.filterAttrs (_: v: v != null) dirs;
    in lib.flatten (getPaths dirs');

  # getPaths :: AttrSet -> [str]
  getPaths = dirs:
    let getPath = _: v: if lib.isString v then v else getPaths v;
    in lib.mapAttrsToList getPath dirs;

  # Creates a script from a source file.
  mkScript = name: path:
    let source = builtins.readFile path;
    in pkgs.writeShellScriptBin name source;

  # Creates a nixosSystem configuration from the path.
  # mkHost :: Path -> AttrSet -> nixosSystem
  mkHost = path: args@{system ? sys, ...}:
    lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs lib system; };
      modules = [
        {
          nixpkgs.pkgs = pkgs;
          nixpkgs.config.allowUnfree = true;
          networking.hostName = lib.mkDefault (baseNameOf path);
        }
        (import ./.) # Common config for all NixOS systems
        (import path)
      ];
    };

  # loadHosts :: Path -> AttrSet -> nixosConfigurations
  loadHosts = dir: args:
    mapDir dir (n: path: lib.nameValuePair n (mkHost path args));

  # mkOpt :: Any a -> Any a -> Option a
  mkOpt = type: default: lib.mkOption {
    inherit type default;
  };

  # mkStr :: String -> Option
  mkStr = default: mkOpt lib.types.str default;

  # mbBool :: Bool -> Option
  mkBool = default: mkOpt lib.types.bool default;
}
