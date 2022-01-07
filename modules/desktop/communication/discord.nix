{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.desktop.communication.discord;
in
{
  options.modules.desktop.communication.discord = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.home.packages = with pkgs; [
      discord
    ];
  };
}
