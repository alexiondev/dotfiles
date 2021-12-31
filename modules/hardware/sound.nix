{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.hardware.sound;
in {
  options.modules.hardware.sound = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    sound.enable = true;
    hardware.pulseaudio.enable = true;

    home-manager.users.${config.user.name}.home.packages =
      if config.services.xserver.enable 
      then [ pkgs.pavucontrol pkgs.playerctl ]
      else [];
  };
}