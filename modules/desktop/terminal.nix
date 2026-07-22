{
  config,
  lib,
  pkgs,
  ...
}:
# Alacritty as the desktop terminal, a lightweight GPU renderer that opens
# fast on the laptop's integrated graphics.
let
  cfg = config.modules.desktop.terminal;
  user = config.user.name;
in
{
  options.modules.desktop.terminal.enable = lib.mkEnableOption "Alacritty as the desktop terminal";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [ pkgs.alacritty ];
  };
}
