{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.desktop.term.alacritty;
in {
  options.modules.desktop.term.alacritty = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.programs.alacritty = {
      enable = true;
      settings = {
        font = {
          normal = {
            family = builtins.head config.modules.theme.fonts.default.monospace;
            style  = "Regular";
          };
          size = 8;
        };
      };
    };
  };
}