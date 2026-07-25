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

  # The special arguments every configuration is evaluated with, host and guest
  # interior alike.
  specialArgs = {
    inherit inputs;
    my = self.lib;
  };

  # Build one host: every module and every guest is imported unconditionally
  # (inert until its `enable` flag is set), alongside chaotic, the host base,
  # and the host's own directory.
  mkHost =
    {
      hostName,
      system ? "x86_64-linux",
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system specialArgs;
      modules =
        (collectNixFiles (self + "/modules"))
        ++ (collectNixFiles (self + "/guests"))
        ++ [
          inputs.chaotic.nixosModules.default
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
          inputs.stylix.nixosModules.stylix
          (self + "/system.nix")
          (self + "/hosts/${hostName}")
          { networking.hostName = hostName; }
        ];
    };

  # Build a guest: a module-shaped definition whose body realizes its interior
  # as a nested container standing on the guest-base, keyed by its namespace path.
  # `name` is the dotted namespace under `guests.` and `interior` is an extra
  # module merged into the container alongside the guest-base.
  guest =
    {
      name,
      interior ? { },
    }:
    { config, lib, ... }:
    let
      optionPath = [ "guests" ] ++ lib.splitString "." name;
      cfg = lib.getAttrFromPath optionPath config;
      machineName = lib.replaceStrings [ "." ] [ "-" ] name;
    in
    {
      options = lib.setAttrByPath optionPath {
        enable = lib.mkEnableOption "the ${name} guest, run in its own nested container";
        backend = lib.mkOption {
          type = lib.types.enum [
            "container"
            "microvm"
          ];
          default = "container";
          description = ''
            How the guest is realized. `container` runs the guest as a
            systemd-nspawn nested container. `microvm` is reserved for a future
            hard-isolation backend and is not built yet.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.backend == "container";
            message = ''
              guests.${name}.backend = "${cfg.backend}" is not implemented. Only the "container" backend is built; "microvm" is reserved for future work.
            '';
          }
        ];

        containers.${machineName} = lib.mkIf (cfg.backend == "container") {
          autoStart = lib.mkDefault true;

          # The guest gets its own network namespace, so its services — its own
          # sshd included — never contend with the host's.
          privateNetwork = lib.mkDefault true;

          inherit specialArgs;

          config = {
            imports = [
              (self + "/guest.nix")
              interior
            ];
          };
        };
      };
    };

  # Discover every host (a subdirectory of `hostsDir`) and build each one.
  mkHosts =
    hostsDir:
    let
      hostNames = attrNames (filterAttrs (_name: type: type == "directory") (builtins.readDir hostsDir));
    in
    genAttrs hostNames (hostName: mkHost { inherit hostName; });
in
{
  inherit
    collectNixFiles
    mkHost
    mkHosts
    guest
    ;
}
