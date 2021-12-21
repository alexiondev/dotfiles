{ pkgs, lib, ...}:

# Reference links for i3 configuration:
# https://i3wm.org/docs/userguide.html
# https://github.com/nix-community/home-manager/blob/master/modules/services/window-managers/i3-sway/i3.nix
# https://github.com/nix-community/home-manager/blob/master/modules/services/window-managers/i3-sway/lib/options.nix

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
in {
  xsession.windowManager.i3 = {
    enable = true;
    package = pkgs.i3-gaps;

    config = rec {
      modifier = "${mod}";

      bars = [];

      window.commands = [
        {   criteria.class = "^.*"; 
            command = "border pixel 0"; 
        }{  criteria.class = "Spotify";
            command = "move container to workspace ${workspaces.ws10}";
        }{  criteria.title="(?i)(?:copying/deleting/moving)";
            command = "floating enable";
        }{  criteria.window_role = "(?i)(?:pop-up|setup)";
            command = "floating enable";
        }
      ];

      assigns = {
        "${workspaces.ws1}" = [{ class="(?i)(?:firefox)"; }];
      };

      gaps.inner = 5;

      startup = [
        {
          command = "${exec} i3-msg workspace ${workspaces.ws1}";
          always = false;
        }{
          command = "--no-startup-id ${pkgs.spotify}/bin/spotify";
          always = false;
        }
      ];

      keybindings = {
        # i3 state
        "${mod}+Shift+c" = "reload";
        "${mod}+Shift+r" = "restart";

        # Applications
        "${mod}+Return" = "${exec} ${pkgs.alacritty}/bin/alacritty";
        "${mod}+r"      = "${exec} ${pkgs.rofi}/bin/rofi -modi drun -show drun";
        
        # Windows
        "${mod}+Shift+q" = "kill";

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
        "XF86AudioMute"         = "${exec} ${pkgs.pulseaudio}/bin/pactl set-sink-mute 0 toggle";
        "XF86AudioLowerVolume"  = "${exec} ${pkgs.pulseaudio}/bin/pactl set-sink-volume 0 -5%";
        "XF86AudioRaiseVolume"  = "${exec} ${pkgs.pulseaudio}/bin/pactl set-sink-volume 0 +5%";

        "XF86AudioPlay"         = "${exec} ${pkgs.playerctl}/bin/playerctl play-pause";
        "XF86AudioPrev"         = "${exec} ${pkgs.playerctl}/bin/playerctl previous";
        "XF86AudioNext"         = "${exec} ${pkgs.playerctl}/bin/playerctl next";

        # Screen Brightness
        "XF86MonBrightnessDown" = "${exec} ${pkgs.light}/bin/light -U 5";
        "XF86MonBrightnessUp"   = "${exec} ${pkgs.light}/bin/light -A 5";

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
}
