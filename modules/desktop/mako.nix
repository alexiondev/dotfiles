{
  config,
  lib,
  pkgs,
  ...
}:
# mako as the notification daemon: toasts, a do-not-disturb mode, and history recall.
let
  cfg = config.modules.desktop.mako;
  user = config.user.name;

  makoctl = "${pkgs.mako}/bin/makoctl";
in
{
  options.modules.desktop.mako.enable = lib.mkEnableOption "the mako notification daemon";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      # Colors and the popup font come from Stylix's mako target, so only
      # behaviour is set here.
      services.mako = {
        enable = true;

        settings = {
          # Toasts auto-dismiss into history rather than lingering.
          # mako's own default of 0 leaves every notification on screen until acted on.
          default-timeout = 5000;

          # The do-not-disturb mode.
          # Invisible hides the toasts but still records them to history.
          # Missed notifications can therefore be recalled.
          "mode=dnd".invisible = true;
        };
      };

      # Recall the last notification from history, keyboard-only like the rest
      # of the session.
      # $mod is defined by the compositor config these binds share.
      wayland.windowManager.hyprland.settings.bind = [
        "$mod, N, exec, ${makoctl} restore"
      ];
    };
  };
}
