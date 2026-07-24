{
  config,
  lib,
  pkgs,
  ...
}:
# Screen backlight control via brightnessctl.
let
  cfg = config.modules.desktop.brightness;
  user = config.user.name;
in
{
  options.modules.desktop.brightness.enable = lib.mkEnableOption "brightnessctl backlight control";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.brightnessctl ];

    # The udev rule chgrps each backlight's brightness node to `video` and adds
    # group write, so a member can dim the panel without root.
    services.udev.packages = [ pkgs.brightnessctl ];
    users.users.${user}.extraGroups = [ "video" ];
  };
}
