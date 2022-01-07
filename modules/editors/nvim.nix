{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.editors.nvim;
in
{
  options.modules.editors.nvim = {
    enable = mkBool true;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.programs.neovim = {
      enable = true;
    };

    modules.shell = {
      aliases = {
        v = "nvim";
        vi = "nvim";
        vim = "nvim";
      };

      variables.EDITOR = "nvim";
    };
  };
}
