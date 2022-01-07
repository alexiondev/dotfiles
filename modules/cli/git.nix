{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.cli.git;
in
{
  options.modules.cli.git = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.programs.git = {
      enable = true;
    };
  };
}
