{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.cli.xclip;
in {
  options.modules.cli.xclip = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.home.packages = with pkgs; [
      xclip
    ];
  };
}