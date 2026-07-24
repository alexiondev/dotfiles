{ config, lib, ... }:
# XDG desktop portal routing for in-app screen sharing and file dialogs.
let
  cfg = config.modules.desktop.portals;
in
{
  options.modules.desktop.portals.enable =
    lib.mkEnableOption "XDG desktop portals for in-app screen sharing and file dialogs";

  config = lib.mkIf cfg.enable {
    # The backend packages arrive with the compositor, so only the routing is set
    # here.
    # Screen sharing, screenshots, and global shortcuts need the compositor's
    # own backend.
    # Everything else uses GTK.
    xdg.portal.config.common = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      "org.freedesktop.impl.portal.GlobalShortcuts" = [ "hyprland" ];
    };
  };
}
