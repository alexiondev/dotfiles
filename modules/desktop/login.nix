{
  config,
  lib,
  pkgs,
  ...
}:
# Text login: greetd running the tuigreet greeter, which starts the session
# through the universal Wayland session manager.
let
  cfg = config.modules.desktop.login;
in
{
  options.modules.desktop.login.enable = lib.mkEnableOption "greetd with the tuigreet text greeter";

  config = lib.mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings.default_session.command =
        "${lib.getExe pkgs.tuigreet} --time --remember "
        + "--cmd 'uwsm start -e -D Hyprland hyprland.desktop'";
    };
  };
}
