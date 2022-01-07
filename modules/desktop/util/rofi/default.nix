{ config, lib, pkgs, ... }:

with lib.my;
with lib.types;
let cfg = config.modules.desktop.util.rofi;
in
{
  options.modules.desktop.util.rofi = {
    enable = mkBool false;

    cmd = mkStr "rofi -modi drun -show drun";

    menu = mkOpt attrs {
      power = ./power_menu.sh;
    };
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name} = {
      programs.rofi.enable = true;
      home.packages = lib.mapAttrsToList (name: path: mkScript ("rofi_" + name) path) cfg.menu;
    };
  };
}
