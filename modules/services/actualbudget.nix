{
  config,
  lib,
  my,
  ...
}:
let
  cfg = config.modules.services.actualbudget;
in
{
  options.modules.services.actualbudget = {
    enable = lib.mkEnableOption "Actual Budget";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5006;
      description = "Port Actual Budget listens on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/data";
      description = "Directory where Actual Budget stores server and user files.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "actual";
      description = "User account that runs Actual Budget.";
    };

    uid = lib.mkOption {
      type = lib.types.ints.positive;
      default = my.serviceUid "actualbudget";
      description = "Stable uid for the Actual Budget service user.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "storage";
      description = "Group account that owns Actual Budget's writable state.";
    };

  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      uid = cfg.uid;
      group = cfg.group;
    };

    services.actual = {
      enable = true;
      openFirewall = true;
      user = cfg.user;
      group = cfg.group;
      settings = {
        inherit (cfg) port dataDir;
      };
    };
  };
}
