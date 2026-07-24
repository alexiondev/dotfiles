{
  config,
  lib,
  pkgs,
  ...
}:
# Obsidian as the desktop note-taking vault.
let
  cfg = config.modules.desktop.obsidian;
  user = config.user.name;
in
{
  options.modules.desktop.obsidian.enable = lib.mkEnableOption "Obsidian as the desktop note-taking vault";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [ pkgs.obsidian ];
  };
}
