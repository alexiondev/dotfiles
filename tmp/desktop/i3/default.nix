{ config, lib, mylib, options, ... }:
let cfg = config.modules.desktop.i3;
in {
  options.modules.desktop.i3 = {
    enable = mylib.mkBool false;
  };

  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable = true;
      displayManager.startx.enable = true;
    };
  };
}