{
  config,
  lib,
  my,
  ...
}:
let
  cfg = config.guests.actualbudget;
  dataDir = "/data";
in
{
  imports = [
    (my.guest {
      name = "actualbudget";
      interior = {
        modules.services.actualbudget = {
          enable = true;
          inherit dataDir;
        };
      };
    })
  ];

  options.guests.actualbudget = {
    dataPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/srv/actualbudget";
      description = "Host path bind-mounted as Actual Budget's data directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.dataPath != null;
        message = "guests.actualbudget.dataPath must point at the host directory that stores Actual Budget data.";
      }
    ];

    guests.actualbudget = {
      mounts.${dataDir}.hostPath = cfg.dataPath;
      limits = {
        memory = lib.mkDefault "2G";
        cpu = lib.mkDefault "200%";
        tasksMax = lib.mkDefault 512;
      };
    };
  };
}
