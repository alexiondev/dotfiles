{
  config,
  lib,
  pkgs,
  ...
}:
# The lock screen: a hyprlock session-lock surface the compositor owns.
let
  cfg = config.modules.desktop.hyprland.hyprlock;
  user = config.user.name;

  # The hyprlock this module installs, used by the lock keybind below.
  hyprlock = "${config.home-manager.users.${user}.programs.hyprlock.package}/bin/hyprlock";
in
{
  options.modules.desktop.hyprland.hyprlock.enable = lib.mkEnableOption "the hyprlock lock screen";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      # Colors and the lock-screen background come from Stylix's hyprlock target,
      # so only geometry and behaviour are set here.
      programs.hyprlock = {
        enable = true;

        settings = {
          general = {
            hide_cursor = true;
            # No progress bar flashes before the field is ready to take input.
            disable_loading_bar = true;
          };

          # A centered password field.
          # Its colors come from the Stylix hyprlock target.
          input-field = {
            size = "260, 52";
            rounding = 8;
            position = "0, -100";
            halign = "center";
            valign = "center";
          };

          # The current time, above the field.
          label = {
            text = "$TIME";
            font_size = 48;
            position = "0, 120";
            halign = "center";
            valign = "center";
          };
        };
      };

      # Lock on Super+X.
      # The guard drops the keypress when a locker is already up, so a second
      # hyprlock never stacks over the first.
      wayland.windowManager.hyprland.settings.bind = [
        "$mod, X, exec, ${pkgs.procps}/bin/pidof hyprlock || ${hyprlock}"
      ];
    };
  };
}
