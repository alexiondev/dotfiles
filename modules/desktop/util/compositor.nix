{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.desktop.util.compositor;
in {
  options.modules.desktop.util.compositor = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.services.picom = {
      enable = true;
    };
  };
}