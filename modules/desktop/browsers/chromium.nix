{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.desktop.browsers.chromium;
in
{
  options.modules.desktop.browsers.chromium = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.programs.chromium = {
      enable = true;
    };
  };
}
