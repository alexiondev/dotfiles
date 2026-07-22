{
  config,
  lib,
  pkgs,
  ...
}:
# rofi as the desktop launcher and dmenu-style menu frontend.
let
  cfg = config.modules.desktop.rofi;
  user = config.user.name;

  # A session menu built on the same themed rofi, so the power actions look
  # like every other menu the launcher drives.
  powerMenu = pkgs.writeShellScript "rofi-power-menu" ''
    chosen=$(printf '%s\n' Lock Suspend 'Log out' Reboot 'Shut down' \
      | ${pkgs.rofi}/bin/rofi -dmenu -i -p Power)
    case "$chosen" in
      Lock) ${pkgs.systemd}/bin/loginctl lock-session ;;
      Suspend) ${pkgs.systemd}/bin/systemctl suspend ;;
      'Log out') ${pkgs.systemd}/bin/loginctl terminate-session "$XDG_SESSION_ID" ;;
      Reboot) ${pkgs.systemd}/bin/systemctl reboot ;;
      'Shut down') ${pkgs.systemd}/bin/systemctl poweroff ;;
    esac
  '';
in
{
  options.modules.desktop.rofi.enable = lib.mkEnableOption "the rofi launcher";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      # No theme is set here: Stylix's rofi target supplies the Nord one.
      programs.rofi = {
        enable = true;

        # Application launch is the only mode, kept minimal so the prompt opens
        # as fast as rofi can read the desktop entries.
        # Icons are off: resolving one per entry is the bulk of drun's startup.
        extraConfig = {
          modi = "drun";
          show-icons = false;
        };
      };

      # The launcher and the session menu, kept next to the tool they drive.
      # $mod is defined by the compositor config these binds share.
      wayland.windowManager.hyprland.settings.bind = [
        "$mod, R, exec, ${pkgs.rofi}/bin/rofi -show drun"
        "$mod SHIFT, X, exec, ${powerMenu}"
      ];
    };
  };
}
