{
  lib,
  inputs,
  self,
}:
let
  inherit (lib)
    attrNames
    filterAttrs
    genAttrs
    flatten
    hasSuffix
    mapAttrsToList
    ;

  # --- Auto-loader ---------------------------------------------------------
  # Recursively collect every `.nix` file under `dir`, returned as a flat list
  # of paths suitable for a module `imports`. No null-placeholder traversal
  # hack: a directory recurses, a `.nix` file is taken, anything else is skipped.
  collectNixFiles =
    dir:
    flatten (
      mapAttrsToList (
        name: type:
        let
          path = dir + "/${name}";
        in
        if type == "directory" then
          collectNixFiles path
        else if type == "regular" && hasSuffix ".nix" name then
          [ path ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  # --- Host-builder --------------------------------------------------------
  # Build one Host: every Module is imported unconditionally (inert until its
  # `enable` flag is set), alongside home-manager, chaotic, the shared base,
  # and the Host's own directory.
  mkHost =
    {
      hostName,
      system ? "x86_64-linux",
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs;
        my = self.lib;
      };
      modules =
        (collectNixFiles (self + "/modules"))
        ++ [
          inputs.home-manager.nixosModules.home-manager
          inputs.chaotic.nixosModules.default
          (self + "/system")
          (self + "/hosts/${hostName}")
          { networking.hostName = hostName; }
        ];
    };

  # Discover every Host (a subdirectory of `hostsDir`) and build each one.
  mkHosts =
    hostsDir:
    let
      hostNames = attrNames (filterAttrs (_name: type: type == "directory") (builtins.readDir hostsDir));
    in
    genAttrs hostNames (hostName: mkHost { inherit hostName; });

  # --- Script-from-file helper --------------------------------------------
  # Turn a standalone script file into a package on PATH, keeping the script
  # itself editable as a real file rather than an inlined heredoc.
  scriptFromFile = pkgs: name: path: pkgs.writeShellScriptBin name (builtins.readFile path);
in
{
  inherit
    collectNixFiles
    mkHost
    mkHosts
    scriptFromFile
    ;
}
