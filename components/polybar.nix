{ pkgs, ...}:

let
  colors = {
    bg = "#00000000";
    fg = "#FFFFFF";
    red = "#FF0000";
    green = "#00FF00";
    grey = "#999999";
  };
in {
  home-manager.users.alexion.services.polybar = {
    enable = true;
    package = pkgs.polybar.override {
      i3GapsSupport = true;
      pulseSupport = true;
    };

    script = "DISPLAY=:0 polybar -q -r top & DISPLAY=:0 polybar -q -r bot &";
    config = {
      "settings" = {
        screenchange-reload = true;
      };
      "global/wm" = {
        margin-top = 5;
        margin-bottom = 5;
      };

      "bar/top" = {
        width = "100%";
        height = 20;
        fixed-center = true;
        background = colors.bg;
        foreground = colors.fg;
        scroll-up = "i3wm-wsnext";
        scroll-down = "i3wm-wsprev";
        font-0 = "Hack:size=10;3";
        font-1 = "Font Awesome 5 Free:style=Regular:size=10;2";
        font-2 = "Font Awesome 5 Free:style=Solid:size=10;2";
        font-3 = "Font Awesome 5 Brands:style=Regular:size=10;2";
        module-margin = 1;
        enable-ipc = true;
        cursor-click = "pointer";
        cursor-scroll = "default";

        padding=1;
        modules-left = "spotify";
        modules-center = "title";
        modules-right = "light volume battery time date";
      };

      "bar/bot" = {
        width = "100%";
        height = 20;
        fixed-center = true;
        background = colors.bg;
        foreground = colors.fg;
        scroll-up = "i3wm-wsnext";
        scroll-down = "i3wm-wsprev";
        font-0 = "Hack:size=10;3";
        font-1 = "Font Awesome 5 Free:style=Regular:size=10;2";
        font-2 = "Font Awesome 5 Free:style=Solid:size=10;2";
        font-3 = "Font Awesome 5 Brands:style=Regular:size=10;2";
        module-margin = 1;
        enable-ipc = true;
        cursor-click = "pointer";
        cursor-scroll = "default";

        padding=1;
        bottom = true;
        modules-left = "i3";
        modules-center = "";
        modules-right = "";
      };

      "module/battery" = {
        type = "internal/battery";
        full-at = 99;
        battery = "BAT0";
        adapter = "AC";

        time-format = "%H:%M";
        format-charging = " <animation-charging> <label-charging>";
        format-discharging = "<ramp-capacity> <label-discharging>";
        label-charging = "%percentage%%";
        label-discharging = "%percentage%%";

        ramp-capacity-0 = "";
        ramp-capacity-1 = "";
        ramp-capacity-2 = "";
        ramp-capacity-3 = "";
        ramp-capacity-4 = "";

        animation-charging-0 = "";
        animation-charging-1 = "";
        animation-charging-2 = "";
        animation-charging-3 = "";
        animation-charging-4 = "";
        animation-charging-framerate = 750;
      };

      "module/i3" = {
        type = "internal/i3";
        pin-workspaces = true;
        index-sort = true;
        enable-scroll = false;
        wrapping-scroll = false;

        ws-icon-0 = "1;";
        ws-icon-1 = "2;";
        ws-icon-2 = "3;";
        ws-icon-3 = "4;?";
        ws-icon-4 = "5;?";
        ws-icon-5 = "6;?";
        ws-icon-6 = "7;?";
        ws-icon-7 = "8;?";
        ws-icon-8 = "9;";
        ws-icon-9 = "10;";

        label-focused = "%icon%";
        label-focused-padding = 1;
        label-focused-foreground = colors.fg;

        label-unfocused = "(%name%) %icon%";
        label-unfocused-foreground = colors.grey;
        label-unfocused-padding = 1;

        label-urgent = "%icon%";
        label-urgent-foreground = colors.red;
      };

      "module/title" = {
        type = "internal/xwindow";
        format = "<label>";
        label = "%title%";
        label-maxlen = 70;
      };

      "module/date" = {
        type = "internal/date";
        interval = 1;
        date = "%a %d, %b %Y";

        format = " <date>";
        format-foreground = "#ccccff";
      };

      "module/time" = {
        type = "internal/date";
        interval = 1;
        time = "%H:%M:%S";
        format = "<label>";
        label = "%time%";
      };

      "module/spotify" = let playerctl = "${pkgs.playerctl}/bin/playerctl"; in {
        type = "custom/script";
        exec = "${playerctl} metadata --format \"%{F#00FF00} {{ artist }}: {{ title }}%{F-}\"";
        exec-if = "${playerctl} -l";
        click-left = "${playerctl} previous";
        click-middle = "${playerctl} play-pause";
        click-right = "${playerctl} next";
        interval = 1;
      };

      "module/volume" = {
        type = "internal/pulseaudio";
        use-ui-max = true;
        interval = 5;
        format-volume = "<ramp-volume> <label-volume>";
        format-muted = "<label-muted>";
        label-volume = "%percentage%%";
        label-muted = " muted";
        label-muted-foreground = "${colors.red}";
        ramp-volume-0 = "";
        ramp-volume-1 = "";
        ramp-volume-2 = "";
      };

      "module/light" = {
        type = "custom/script";
        exec = "echo \" $(${pkgs.light}/bin/light)%\"";
        interval = 1;
      };
    };
  };
}