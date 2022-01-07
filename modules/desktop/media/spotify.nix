{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.desktop.media.spotify;
in
{
  options.modules.desktop.media.spotify = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.home.packages = with pkgs; [
      spotify
    ];
  };
}
