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

  # Recursively collect every `.nix` file under `dir` as a flat list, for a
  # module's `imports`.
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

  # Build one host: every module is imported unconditionally (inert until its
  # `enable` flag is set), alongside home-manager, chaotic, the shared base, and
  # the host's own directory.
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
          inputs.disko.nixosModules.disko
          (self + "/system")
          (self + "/hosts/${hostName}")
          { networking.hostName = hostName; }
        ];
    };

  # Discover every host (a subdirectory of `hostsDir`) and build each one.
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
