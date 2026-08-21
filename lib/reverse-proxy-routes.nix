{ lib }:
let
  mkRouteOptions =
    {
      name ? null,
      subject ? "route",
      enableDefault ? true,
    }:
    {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = enableDefault;
        description = "Whether this reverse-proxy ${subject} is active.";
      };

      host = lib.mkOption (
        {
          type = lib.types.str;
          description = "Primary hostname served by this reverse-proxy ${subject}.";
        }
        // lib.optionalAttrs (name != null) {
          default = name;
          defaultText = lib.literalMD "the route attribute name";
        }
      );

      aliases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional hostnames served by this reverse-proxy ${subject}.";
      };

      path = lib.mkOption {
        type = lib.types.str;
        default = "/";
        description = "URL path prefix proxied by this reverse-proxy ${subject}.";
      };

      backend = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Full HTTP backend URL that receives proxied traffic.";
      };

      endpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Fleet network endpoint key used to derive the backend URL.";
      };

      port = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 1 65535);
        default = null;
        example = 3923;
        description = "Backend TCP port used with the fleet network endpoint.";
      };

      scheme = lib.mkOption {
        type = lib.types.str;
        default = "http";
        description = "Backend URL scheme used with the fleet network endpoint.";
      };

      tls = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to serve this reverse-proxy ${subject} with ACME-backed TLS.";
      };

      websockets = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable websocket proxy headers for this reverse-proxy ${subject}.";
      };
    };

  routeFields = route: {
    inherit (route)
      host
      aliases
      path
      backend
      endpoint
      port
      scheme
      tls
      websockets
      ;
  };

  endpointBackend = endpoints: route:
    let
      endpoint = endpoints.${route.endpoint} or (
        throw "Unknown reverse-proxy endpoint `${route.endpoint}`. Known endpoints: ${lib.concatStringsSep ", " (lib.attrNames endpoints)}"
      );
    in
    "${route.scheme}://${endpoint.address}:${toString route.port}";

  resolvedRouteFields = endpoints: route:
    let
      routeWithBackend =
        if route.backend != null then
          route
        else if route.endpoint != null && route.port != null then
          route // { backend = endpointBackend endpoints route; }
        else
          throw "Reverse-proxy route `${route.host}${route.path}` needs either backend or endpoint plus port.";
    in
    routeFields routeWithBackend;

  collectFleetRoutes =
    hosts: endpoints:
    lib.concatMapAttrs (
      hostName: host:
      lib.mapAttrs' (
        routeName: route: lib.nameValuePair "${hostName}-${routeName}" (resolvedRouteFields endpoints route)
      ) host.config.modules.reverse-proxy.routes
    ) hosts;
in
{
  inherit collectFleetRoutes mkRouteOptions resolvedRouteFields routeFields;

  routeType = lib.types.submodule (
    { name, ... }:
    {
      options = mkRouteOptions { inherit name; };
    }
  );
}
