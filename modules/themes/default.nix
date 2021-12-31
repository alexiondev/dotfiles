{ config, lib, options, pkgs, ... }:

with lib.my;
let cfg = config.modules.theme;
in {
  options.modules.theme = with lib.types; {
    active = mkOpt (nullOr str) null;

    fonts = mkOpt (listOf str) [];
  };

  config = lib.mkIf (cfg.active != null) {
    home-manager.users.${config.user.name} = {
      home.packages = cfg.fonts;
    };
  };
}