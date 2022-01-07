{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.desktop.util.redshift;
in {
  options.modules.desktop.util.redshift = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    services.redshift = {
      enable = true;
      temperature = {
        day = 5500;
        night = 3000;
      };
    };

    location = {
      latitude = 42.38;
      longitude = -71.24;
    };
  };
}
