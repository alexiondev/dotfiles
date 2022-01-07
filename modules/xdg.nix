{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.xdg;
in
{
  options.modules.xdg = {
    enable = mkBool true;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.xdg = {
      enable = true;
      userDirs = {
        enable = true;
        createDirectories = true;

        desktop = "$HOME/.desktop";
        documents = "$HOME/doc";
        download = "$HOME/dwn";
        music = "$HOME/.hideme";
        pictures = "$HOME/pic";
        publicShare = "$HOME/.hideme";
        templates = "$HOME/.hideme";
        videos = "$HOME/.hideme";
      };
    };
  };
}
