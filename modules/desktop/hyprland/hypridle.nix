{
  config,
  lib,
  pkgs,
  ...
}:
# Idle management: hypridle locks on idle, powers the displays off, and locks
# before every suspend, so an unattended session always lands at hyprlock.
let
  cfg = config.modules.desktop.hypridle;
  user = config.user.name;

  hyprctl = "${config.programs.hyprland.package}/bin/hyprctl";
  hyprlock = "${config.home-manager.users.${user}.programs.hyprlock.package}/bin/hyprlock";

  # The guard drops the call when a locker is already up, so no idle trigger
  # stacks a second hyprlock over the first.
  lockCmd = "${pkgs.procps}/bin/pidof hyprlock || ${hyprlock}";
in
{
  options.modules.desktop.hypridle = {
    enable = lib.mkEnableOption "hypridle idle management";

    lockTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Seconds of inactivity before the screen locks.";
    };

    screenOffTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 360;
      description = "Seconds of inactivity before the displays are powered off.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Closing the lid suspends, and every suspend locks first through the
    # before_sleep_cmd below, so the lid always lands at a locked screen.
    services.logind.settings.Login.HandleLidSwitch = "suspend";

    home-manager.users.${user}.services.hypridle = {
      enable = true;

      settings = {
        general = {
          lock_cmd = lockCmd;
          before_sleep_cmd = "loginctl lock-session";
          # Waking restores the displays the screen-off listener may have cut.
          after_sleep_cmd = "${hyprctl} dispatch dpms on";
        };

        listener = [
          # Lock on idle.
          {
            timeout = cfg.lockTimeout;
            on-timeout = "loginctl lock-session";
          }
          # Power the displays off a little later, restoring them on any activity.
          {
            timeout = cfg.screenOffTimeout;
            on-timeout = "${hyprctl} dispatch dpms off";
            on-resume = "${hyprctl} dispatch dpms on";
          }
        ];
      };
    };
  };
}
