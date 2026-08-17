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
        type = lib.types.str;
        description = "Full HTTP backend URL that receives proxied traffic.";
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
      tls
      websockets
      ;
  };
in
{
  inherit mkRouteOptions routeFields;

  routeType = lib.types.submodule (
    { name, ... }:
    {
      options = mkRouteOptions { inherit name; };
    }
  );
}
