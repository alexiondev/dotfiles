{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.desktop.i3;
in {
  options.modules.desktop.i3 = {
    enable = mkBool false;
  };

  config =
  let
    mod   = "Mod4";
    exec  = "exec --no-startup-id";

    # Directions
    left  = "h";
    down  = "j";
    up    = "k";
    right = "l";

    # Workspaces
    workspaces = {
      ws1  = "1";
      ws2  = "2";
      ws3  = "3";
      ws4  = "4";
      ws5  = "5";
      ws6  = "6";
      ws7  = "7";
      ws8  = "8";
      ws9  = "9";
      ws10 = "10";
    };

    # Programs
    audioctl  = "pactl";
    launcher  = config.modules.desktop.util.rofi.cmd;
    lightctl  = "light";
    mediactl  = "playerctl";
    spotify   = "spotify";
    terminal  = "alacritty";
    screenshot = config.modules.desktop.util.screenshot;
  in lib.mkIf cfg.enable {
    home-manager.users.${config.user.name}.xsession.windowManager.i3 = {
      enable = true;
      package = pkgs.i3-gaps;

      config = {
        modifier = mod;
        bars = [];

        window.commands = [
          {   criteria.class = "^.*";
              command = "border pixel 0";
          }{  criteria.class = "Spotify";
              command = "move container to workspace ${workspaces.ws10}";
          }{  criteria.title = "(?i)(?:copying/deleting/moving)";
              command = "floating enable";
          }{  criteria.window_role = "(?i)(?:pop-up|setup)";
              command = "floating enable";
          }
        ];

        assigns = {
          "${workspaces.ws1}" = [{ class = "(?i)(?:firefox)"; }];
        };

        gaps.inner = 5;

        startup = [
          {   command = "exec i3-msg workspace ${workspaces.ws1}";
              always = false;
              notification = false;
          }{  command = "${spotify}";
              always = false;
              notification = false;
          }{  command = "systemctl --user restart picom.service";
              always = true;
              notification = false;
          }{  command = "systemctl --user restart polybar.service";
              always = true;
              notification = false;
          }{  command = "systemctl --user restart redshift.service";
              always = true;
              notification = false;
          }
        ];

        keybindings = {
          # i3 State
          "${mod}+Shift+c"  = "reload";
          "${mod}+Shift+r"  = "restart";
          "${mod}+Shift+x"  = "${exec} rofi_power";

          # Applications
          "${mod}+Return"   = "${exec} ${terminal}";
          "${mod}+r"        = "${exec} ${launcher}";

          # Windows
          "${mod}+Shift+q"  = "kill";

          "${mod}+${left}"  = "focus left";
          "${mod}+${down}"  = "focus down";
          "${mod}+${up}"    = "focus up";
          "${mod}+${right}" = "focus right";
          "${mod}+space"    = "focus mode_toggle";

          "${mod}+Shift${left}"   = "move left 10px";
          "${mod}+Shift${down}"   = "move down 10px";
          "${mod}+Shift${up}"     = "move up 10px";
          "${mod}+Shift${right}"  = "move right 10px";

          "${mod}+Mod1+${left}"   = "resize shrink width 10 px or 10 ppt";
          "${mod}+Mod1+${down}"   = "resize grow height 10 px or 10 ppt";
          "${mod}+Mod1+${up}"     = "resize shrink height 10px or 10 ppt";
          "${mod}+Mod1+${right}"  = "resize grow width 10px or 10 ppt";

          # Layout
          "${mod}+v"            = "split toggle";
          "${mod}+f"            = "fullscreen";
          "${mod}+t"            = "layout toggle tabbed splith splitv";
          "${mod}+Shift+space"  = "floating toggle";

          # Media
          "XF86AudioMute"         = "${exec} ${audioctl} set-sink-mute 0 toggle";
          "XF86AudioLowerVolume"  = "${exec} ${audioctl} set-sink-volume 0 -5%";
          "XF86AudioRaiseVolume"  = "${exec} ${audioctl} set-sink-volume 0 +5%";

          "XF86AudioPlay"         = "${exec} ${mediactl} play-pause";
          "XF86AudioPrev"         = "${exec} ${mediactl} previous";
          "XF86AudioNext"         = "${exec} ${mediactl} next";

          # Screen Brightness
          "XF86MonBrightnessDown" = "${exec} ${lightctl} -U 5";
          "XF86MonBrightnessUp"   = "${exec} ${lightctl} -A 5";

          # Screenshots
          "--release Print"       = "${exec} ${screenshot.select}";
          "--release Ctrl+Print"  = "${exec} ${screenshot.full}";
          "--release Shift+Print" = "${exec} ${screenshot.window}";

          # Workspaces
          "${mod}+1"        = "workspace ${workspaces.ws1}";
          "${mod}+2"        = "workspace ${workspaces.ws2}";
          "${mod}+3"        = "workspace ${workspaces.ws3}";
          "${mod}+4"        = "workspace ${workspaces.ws4}";
          "${mod}+5"        = "workspace ${workspaces.ws5}";
          "${mod}+6"        = "workspace ${workspaces.ws6}";
          "${mod}+7"        = "workspace ${workspaces.ws7}";
          "${mod}+8"        = "workspace ${workspaces.ws8}";
          "${mod}+9"        = "workspace ${workspaces.ws9}";
          "${mod}+0"        = "workspace ${workspaces.ws10}";

          "${mod}+Shift+1"  = "move container to workspace ${workspaces.ws1}";
          "${mod}+Shift+2"  = "move container to workspace ${workspaces.ws2}";
          "${mod}+Shift+3"  = "move container to workspace ${workspaces.ws3}";
          "${mod}+Shift+4"  = "move container to workspace ${workspaces.ws4}";
          "${mod}+Shift+5"  = "move container to workspace ${workspaces.ws5}";
          "${mod}+Shift+6"  = "move container to workspace ${workspaces.ws6}";
          "${mod}+Shift+7"  = "move container to workspace ${workspaces.ws7}";
          "${mod}+Shift+8"  = "move container to workspace ${workspaces.ws8}";
          "${mod}+Shift+9"  = "move container to workspace ${workspaces.ws9}";
          "${mod}+Shift+0"  = "move container to workspace ${workspaces.ws10}";
        };
      };
    };
  };
}
