{ config, lib, my, ... }:
let
  cfg = config.modules.reverse-proxy;
  inherit (my) reverseProxyRoutes;

  enabledRoutes = lib.filterAttrs (_: route: route.enable) cfg.routes;
  routesByHost = lib.groupBy (route: route.host) (lib.attrValues enabledRoutes);

  rootRoutesByHost = lib.mapAttrs (
    host: routes:
    let
      roots = builtins.filter (route: route.path == "/") routes;
    in
    if roots == [ ] then null else builtins.head roots
  ) routesByHost;

  hasDuplicatePaths = routes:
    let
      paths = map (route: route.path) routes;
    in
    lib.length paths != lib.length (lib.unique paths);

  hasUnresolvedBackend = route: route.backend == null;

  mkLocation = route: {
    proxyPass = route.backend;
    proxyWebsockets = route.websockets;
  };

  mkVirtualHost = host: routes:
    let
      rootRoute = rootRoutesByHost.${host};
    in
    lib.mkIf (rootRoute != null) {
      forceSSL = rootRoute.tls;
      enableACME = rootRoute.tls;
      serverAliases = rootRoute.aliases;
      locations = lib.listToAttrs (
        map (route: lib.nameValuePair route.path (mkLocation route)) (
          builtins.filter (route: route.backend != null) routes
        )
      );
    };
in
{
  options.modules.reverse-proxy = {
    enable = lib.mkEnableOption "the Nginx reverse proxy route realizer";

    routes = lib.mkOption {
      type = lib.types.attrsOf reverseProxyRoutes.routeType;
      default = { };
      description = "Reverse-proxy route declarations keyed by stable route name.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.mapAttrsToList (host: rootRoute: {
        assertion = rootRoute != null;
        message = "modules.reverse-proxy.routes for ${host} must include a primary / route.";
      }) rootRoutesByHost
      ++ lib.mapAttrsToList (host: routes: {
        assertion = !hasDuplicatePaths routes;
        message = "modules.reverse-proxy.routes for ${host} must not declare the same path more than once.";
      }) routesByHost
      ++ map (route: {
        assertion = !hasUnresolvedBackend route;
        message = "modules.reverse-proxy.routes for ${route.host}${route.path} must resolve to a backend URL before actualization.";
      }) (builtins.filter hasUnresolvedBackend (lib.attrValues enabledRoutes));

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    security.acme = {
      acceptTerms = true;
      defaults.email = "contact@alexion.dev";
    };

    services.nginx = {
      enable = true;
      commonHttpConfig = ''
        server {
          listen 0.0.0.0:443 ssl default_server;
          listen [::0]:443 ssl default_server;
          ssl_reject_handshake on;
        }
      '';
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = lib.mapAttrs mkVirtualHost routesByHost;
    };
  };
}
