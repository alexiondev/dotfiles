{ config, lib, ... }:
# Declares the XDG user directories, so a tool that queries them lands in a
# well-known folder a host can relocate from one place.
let
  cfg = config.modules.desktop.userdirs;
  user = config.user.name;
in
{
  options.modules.desktop.userdirs.enable = lib.mkEnableOption "XDG user directories";

  config = lib.mkIf cfg.enable {
    # enable writes ~/.config/user-dirs.dirs from the option defaults, which
    # xdg-user-dir then reads.
    home-manager.users.${user}.xdg.userDirs.enable = true;
  };
}
