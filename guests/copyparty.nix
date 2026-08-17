{
  config,
  lib,
  my,
  ...
}:
let
  cfg = config.guests.copyparty;
  serviceUid = my.serviceUid "copyparty";

  volumeType = lib.types.submodule {
    options = {
      hostPath = lib.mkOption {
        type = lib.types.str;
        description = "Host path bind-mounted into the Copyparty guest for this volume.";
      };

      path = lib.mkOption {
        type = lib.types.str;
        description = "Guest path served by this Copyparty volume.";
      };

      access = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = { };
        description = "Copyparty access map from permission string to account names.";
      };

      flags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Copyparty volume flags.";
      };
    };
  };
in
{
  imports = [
    (my.guest {
      name = "copyparty";
      interior = {
        modules.services.copyparty = {
          enable = true;
          inherit (cfg) accountName stateDir;
          passwordFile = "/run/secrets/${cfg.passwordSecret}";
          reverseProxy = {
            enable = cfg.reverseProxy.enable;
            inherit (cfg.reverseProxy) trustedSources;
          };
          volumes = lib.mapAttrs (_urlPath: volume: {
            inherit (volume) path access flags;
          }) cfg.volumes;
        };
      };
    })
  ];

  options.guests.copyparty = {
    accountName = lib.mkOption {
      type = lib.types.str;
      default = "alexion";
      description = "Copyparty account name configured for password authentication.";
    };

    passwordSecret = lib.mkOption {
      type = lib.types.str;
      default = "services/copyparty/users/alexion/password";
      description = "SOPS secret name containing the Copyparty account password.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/copyparty";
      description = "Guest path where Copyparty stores service state.";
    };

    statePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/srv/copyparty";
      description = "Host path bind-mounted as Copyparty's state directory.";
    };

    reverseProxy.trustedSources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "IP ranges that may supply Copyparty's forwarded client IP header.";
    };

    volumes = lib.mkOption {
      type = lib.types.attrsOf volumeType;
      default = { };
      description = "Copyparty volumes keyed by their URL path.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.statePath != null;
        message = "guests.copyparty.statePath must point at the host directory that stores Copyparty state.";
      }
      {
        assertion = cfg.volumes != { };
        message = "guests.copyparty.volumes must declare the host's served Copyparty volumes.";
      }
    ];

    guests.copyparty = {
      secrets = [ cfg.passwordSecret ];
      mounts =
        {
          ${cfg.stateDir} = {
            hostPath = cfg.statePath;
            create = {
              owner = serviceUid;
              group = "storage";
              mode = "0770";
            };
          };
        }
        // lib.mapAttrs' (_urlPath: volume: lib.nameValuePair volume.path { inherit (volume) hostPath; }) cfg.volumes;
      limits = {
        memory = lib.mkDefault "2G";
        cpu = lib.mkDefault "200%";
        tasksMax = lib.mkDefault 512;
      };
    };

    sops.secrets.${cfg.passwordSecret} = {
      owner = "root";
      group = "storage";
      mode = "0440";
    };
  };
}
