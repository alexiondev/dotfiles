{
  config,
  lib,
  pkgs,
  ...
}:
# SwayOSD: a transient on-screen popup for volume and brightness changes.
let
  cfg = config.modules.desktop.osd;
  user = config.user.name;
in
{
  options.modules.desktop.osd.enable = lib.mkEnableOption "the SwayOSD volume and brightness popup";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.swayosd ];

    # The udev rule chgrps each backlight's brightness node to `video` and adds
    # group write, so the server dims the panel without root. Membership below
    # grants the running session that access.
    services.udev.packages = [ pkgs.swayosd ];
    users.users.${user}.extraGroups = [ "video" ];

    # The server draws the popups, so it runs for the whole graphical session.
    # Bound to the target uwsm activates, like the bar, rather than an
    # exec-once in the compositor config.
    home-manager.users.${user}.systemd.user.services.swayosd = {
      Unit = {
        Description = "SwayOSD on-screen display server";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.swayosd}/bin/swayosd-server";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
