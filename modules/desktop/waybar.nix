{
  config,
  lib,
  pkgs,
  ...
}:
# Waybar: a top status bar reading system state at a glance.
let
  cfg = config.modules.desktop.waybar;
  user = config.user.name;

  # A Nerd Font Private-Use-Area codepoint as a literal character, decoded
  # through JSON so the glyph survives as bytes rather than an editor paste.
  g = code: builtins.fromJSON ''"\u${code}"'';

  # Renders and toggles mako's do-not-disturb mode.
  # With no mako daemon answering, the status reads "notifications on", keeping
  # the widget inert rather than broken.
  dndStatus = pkgs.writeShellScript "waybar-dnd-status" ''
    if ${pkgs.mako}/bin/makoctl mode 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx dnd; then
      printf '{"text":"${g "f1f6"}","tooltip":"Do not disturb: on","class":"dnd"}\n'
    else
      printf '{"text":"${g "f0f3"}","tooltip":"Notifications on","class":"active"}\n'
    fi
  '';

  dndToggle = pkgs.writeShellScript "waybar-dnd-toggle" ''
    ${pkgs.mako}/bin/makoctl mode -t dnd >/dev/null 2>&1
    ${pkgs.procps}/bin/pkill -RTMIN+8 waybar
  '';

  # Lit while a wf-recorder capture is running.
  # Empty text collapses the widget when idle, so it shows nothing until then.
  recStatus = pkgs.writeShellScript "waybar-recording-status" ''
    if ${pkgs.procps}/bin/pgrep -x wf-recorder >/dev/null; then
      printf '{"text":"${g "f03d"}","tooltip":"Recording","class":"recording"}\n'
    else
      printf '{"text":"","class":"idle"}\n'
    fi
  '';
in
{
  options.modules.desktop.waybar.enable = lib.mkEnableOption "the Waybar status bar";

  config = lib.mkIf cfg.enable {
    # A symbols font backs the module glyphs, so pango falls back to it for the
    # codepoints Stylix's monospace font does not carry.
    fonts.packages = [ pkgs.nerd-fonts.symbols-only ];

    home-manager.users.${user}.programs.waybar = {
      enable = true;

      # A user service bound to graphical-session.target, which uwsm activates,
      # so the bar comes up with the session and no compositor exec-once.
      systemd.enable = true;

      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 30;

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "custom/recording"
          "mpris"
          "wireplumber"
          "network"
          "battery"
          "custom/dnd"
        ];

        # Per-application icons for the windows on each workspace, mapped from
        # window class with a neutral glyph for anything unlisted.
        "hyprland/workspaces" = {
          on-click = "activate";
          format = "{id} {windows}";
          format-window-separator = " ";
          window-rewrite-default = g "f2d0";
          window-rewrite = {
            "class<Alacritty>" = g "f120";
            "class<.*[Ff]irefox.*>" = g "f269";
            "class<chromium.*>" = g "f268";
            "class<[Cc]ode>" = g "f121";
          };
        };

        clock = {
          format = "{:%a %d %b  %H:%M}";
          tooltip-format = "<tt>{calendar}</tt>";
          calendar = {
            mode = "month";
            # Underline the current day so it stands out in the grid.
            format.today = "<b><u>{}</u></b>";
          };
        };

        mpris = {
          format = "${g "f001"} {title}";
          format-paused = "${g "f04c"} {title}";
          max-length = 40;
          on-click = "play-pause";
          on-scroll-up = "next";
          on-scroll-down = "previous";
        };

        wireplumber = {
          format = "{icon} {volume}%";
          format-muted = "${g "f026"} muted";
          format-icons = [
            (g "f026")
            (g "f027")
            (g "f028")
          ];
          on-click = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };

        network = {
          format-wifi = "${g "f1eb"} {essid}";
          format-ethernet = "${g "f796"} {ifname}";
          format-disconnected = "${g "f127"} off";
          tooltip-format = "{ipaddr} via {gwaddr}";
        };

        battery = {
          format = "{icon} {capacity}%";
          format-charging = "${g "f0e7"} {capacity}%";
          format-icons = [
            (g "f244")
            (g "f243")
            (g "f242")
            (g "f241")
            (g "f240")
          ];
          states = {
            warning = 20;
            critical = 10;
          };
        };

        "custom/dnd" = {
          return-type = "json";
          exec = "${dndStatus}";
          on-click = "${dndToggle}";
          interval = "once";
          signal = 8;
        };

        # Recording state has no event to hook, so the widget samples the
        # wf-recorder process once a second.
        "custom/recording" = {
          return-type = "json";
          exec = "${recStatus}";
          interval = 1;
        };
      };
    };
  };
}
