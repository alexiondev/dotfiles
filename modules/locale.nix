{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.locale;
in {
  options.modules.locale = {
    timezone  = mkStr "America/New_York";
    locale    = mkStr "en_US.UTF-8";
  };

  config = lib.mkIf (cfg.timezone != null) {
    time.timeZone = cfg.timezone;

    i18n.defaultLocale = cfg.locale;
  };
}