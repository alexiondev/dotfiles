{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.desktop.util.brightness;
in
{
  options.modules.desktop.util.brightness = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    programs.light.enable = true;
    user.extraGroups = [ "video" ];
  };
}
