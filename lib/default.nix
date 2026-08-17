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

  serviceIdentityRegistry = import ./service-identities.nix { inherit lib; };
  reverseProxyRoutes = import ./reverse-proxy-routes.nix { inherit lib; };

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

  specialArgs = {
    inherit inputs;
    my = self.lib;
  };

  bridgeName = id: "br-vlan${toString id}";

  guests = import ./guests.nix {
    inherit
      lib
      self
      specialArgs
      bridgeName
      reverseProxyRoutes
      ;
  };

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
    bridgeName
    reverseProxyRoutes
    ;

  inherit (guests) deriveMac guest;

  inherit (serviceIdentityRegistry) serviceUid;
  serviceIdentities = serviceIdentityRegistry.identities;
}
