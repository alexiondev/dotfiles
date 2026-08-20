{ lib }:
let
  endpointOptions = {
    address = lib.mkOption {
      type = lib.types.str;
      example = "10.23.20.126";
      description = "Expected IP address assigned outside NixOS for this network endpoint.";
    };
  };

  endpointType = lib.types.submodule {
    options = endpointOptions;
  };

  endpointFields = endpoint: {
    inherit (endpoint) address;
  };

  collectFleetEndpoints =
    hosts:
    lib.concatMapAttrs (
      hostName: host:
      let
        cfg = host.config.modules.network;
        hostEndpoint = lib.optionalAttrs (cfg.endpoint.address != null) {
          ${hostName} = endpointFields cfg.endpoint;
        };
        guestEndpoints = lib.mapAttrs' (
          endpointName: endpoint: lib.nameValuePair "${hostName}-${endpointName}" (endpointFields endpoint)
        ) cfg.endpoints;
      in
      hostEndpoint // guestEndpoints
    ) hosts;
in
{
  inherit
    collectFleetEndpoints
    endpointFields
    endpointOptions
    endpointType
    ;
}
