{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.desktop.startx;
in {
  options.modules.desktop.startx = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    services.xserver = {
      enable = true;
      displayManager.startx.enable = true;
    };

    systemd.globalEnvironment.DISPLAY = ":0";

    environment.loginShellInit = lib.mkBefore ''
      [[ -z $DISPLAY && $(tty) == /dev/tty1 ]] && startx
    '';
  };
}
