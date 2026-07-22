{
  config,
  lib,
  pkgs,
  ...
}:
# Ghostty as the desktop terminal.
let
  cfg = config.modules.desktop.terminal;
  user = config.user.name;
in
{
  options.modules.desktop.terminal.enable = lib.mkEnableOption "Ghostty as the desktop terminal";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [ pkgs.ghostty ];
  };
}
