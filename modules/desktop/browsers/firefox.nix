{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.desktop.browsers.firefox;
in {
  options.modules.desktop.browsers.firefox = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.programs.firefox = {
      enable = true;
    };
  };
}