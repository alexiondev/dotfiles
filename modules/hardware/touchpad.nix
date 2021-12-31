{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.hardware.touchpad;
in {
  options.modules.hardware.touchpad = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    services.xserver.libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        tappingDragLock = true;
        scrollMethod = "twofinger";
        naturalScrolling = false;
        horizontalScrolling = true;
        disableWhileTyping = true;
      };
    };
  };
}