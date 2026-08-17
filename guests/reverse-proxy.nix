{
  config,
  lib,
  my,
  reverseProxyFleetRoutes ? config.modules.reverse-proxy.routes,
  ...
}:
let
  giteaSshBackend = "10.23.20.45:2022";
  legacyBackend = "http://10.23.20.32";
  legacyHosts = [
    "games.alexion.dev"
    "git.alexion.dev"
    "music.alexion.dev"
    "photos.alexion.dev"
    "plex.alexion.dev"
    "servers.alexion.dev"
    "todo.alexion.dev"
    "wings.alexion.dev"
  ];
  legacyRoutes = lib.listToAttrs (
    map (host: {
      name = "legacy-${lib.replaceStrings [ "." ] [ "-" ] host}";
      value = {
        inherit host;
        backend = legacyBackend;
      };
    }) legacyHosts
  );
in
{
  imports = [
    (my.guest {
      name = "reverse-proxy";
      interior = {
        modules.reverse-proxy = {
          enable = true;
          routes = reverseProxyFleetRoutes // legacyRoutes;
        };

        networking.firewall.allowedTCPPorts = [ 2022 ];

        services.nginx.streamConfig = ''
          server {
            listen 2022;
            proxy_pass ${giteaSshBackend};
          }
        '';
      };
    })
  ];

  config = lib.mkIf config.guests.reverse-proxy.enable {
    guests.reverse-proxy = {
      limits = {
        memory = lib.mkDefault "1G";
        cpu = lib.mkDefault "100%";
        tasksMax = lib.mkDefault 256;
      };
    };
  };
}
