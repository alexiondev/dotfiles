{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.hardware.keyboard;
in {
  options.modules.hardware.keyboard = {
    keymap        = mkStr "us";
    capsIsEscape  = mkBool true;
  };

  config = {
    console.keyMap = cfg.keymap;
    services.xserver.layout = cfg.keymap;

    services.xserver.xkbOptions = builtins.concatStringsSep " " [
      (if cfg.capsIsEscape then "caps:swapescape" else "")
    ];
  };
}