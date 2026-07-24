{
  config,
  lib,
  pkgs,
  ...
}:
# The Hyprland compositor.
let
  cfg = config.modules.desktop.hyprland;
  user = config.user.name;
  cursor = config.stylix.cursor;

  # Numbered-workspace switch and move for 1..9, the operator's i3 muscle memory.
  workspaceBinds = lib.concatMap (n: [
    "$mod, ${toString n}, workspace, ${toString n}"
    "$mod SHIFT, ${toString n}, movetoworkspace, ${toString n}"
  ]) (lib.range 1 9);

  # Flip the tiling strategy between the two built-in layouts, since neither a
  # dispatcher nor a keyword toggles it on its own.
  toggleLayout = pkgs.writeShellScript "hypr-toggle-layout" ''
    if [ "$(hyprctl getoption -j general:layout | ${pkgs.jq}/bin/jq -r .str)" = dwindle ]; then
      hyprctl keyword general:layout master
    else
      hyprctl keyword general:layout dwindle
    fi
  '';
in
{
  options.modules.desktop.hyprland = {
    enable = lib.mkEnableOption "the Hyprland compositor";

    blur = lib.mkEnableOption ''
      window blur. Off by default as the single biggest battery cost on a
      laptop, left on for a host with the headroom to spend it'';
  };

  config = lib.mkIf cfg.enable {
    # This program integration owns the session, portals, and polkit, launched
    # through the universal Wayland session manager.
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    home-manager.users.${user}.wayland.windowManager.hyprland = {
      enable = true;

      # One package drives the whole session, so there is never a version split.
      # The program integration above installs it and the portal, leaving home-
      # manager to write only the config.
      package = null;
      portalPackage = null;

      # uwsm owns the systemd graphical-session targets.
      systemd.enable = false;

      # Write the native hyprlang hyprland.conf, whose variable and bind syntax
      # the settings below are expressed in.
      configType = "hyprlang";

      settings = {
        "$mod" = "SUPER";
        "$terminal" = "alacritty";

        # Hand the cursor theme to the compositor directly.
        # UWSM launches the session without the shell profile that carries the
        # pointer-cursor variables, so without this Hyprland never sees a theme
        # and falls back to its built-in cursor.
        # Bibata ships XCursor only.
        # The hyprcursor variables name the same theme, which Hyprland resolves
        # through its XCursor fallback.
        env = lib.optionals (cursor != null) [
          "XCURSOR_THEME,${cursor.name}"
          "XCURSOR_SIZE,${toString cursor.size}"
          "HYPRCURSOR_THEME,${cursor.name}"
          "HYPRCURSOR_SIZE,${toString cursor.size}"
        ];

        input = {
          kb_layout = "us";
          # Caps is a second Escape.
          # Shift+Caps still toggles a real CapsLock.
          kb_options = "caps:escape_shifted_capslock";
          # Snappy key repeat.
          repeat_delay = 250;
          repeat_rate = 45;
          accel_profile = "flat";
          touchpad = {
            natural_scroll = true;
            tap-to-click = true;
            disable_while_typing = true;
          };
        };

        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          layout = "dwindle";
        };

        decoration = {
          rounding = 6;
          blur.enabled = cfg.blur;
        };

        animations = {
          enabled = true;
          bezier = [ "ease, 0.25, 0.1, 0.25, 1.0" ];
          # Durations are in centiseconds.
          # Short values keep the motion subtle.
          animation = [
            "windows, 1, 3, ease"
            "fade, 1, 3, ease"
            # Layer surfaces like the launcher fade in a touch quicker than windows.
            "layersIn, 1, 2, ease"
            "fadeLayersIn, 1, 2, ease"
            "workspaces, 1, 3, ease"
            "border, 1, 3, ease"
          ];
        };

        dwindle = {
          preserve_split = true;
        };

        bind = [
          "$mod, Return, exec, $terminal"

          # Move focus.
          "$mod, H, movefocus, l"
          "$mod, J, movefocus, d"
          "$mod, K, movefocus, u"
          "$mod, L, movefocus, r"

          # Move the window within the layout.
          "$mod SHIFT, H, movewindow, l"
          "$mod SHIFT, J, movewindow, d"
          "$mod SHIFT, K, movewindow, u"
          "$mod SHIFT, L, movewindow, r"

          # Resize the active window.
          "$mod ALT, H, resizeactive, -40 0"
          "$mod ALT, J, resizeactive, 0 40"
          "$mod ALT, K, resizeactive, 0 -40"
          "$mod ALT, L, resizeactive, 40 0"

          "$mod, Space, togglefloating,"
          "$mod, F, fullscreen,"
          # togglesplit is a dwindle layout message, reached through layoutmsg.
          "$mod, T, layoutmsg, togglesplit"
          "$mod SHIFT, T, exec, ${toggleLayout}"
          "$mod SHIFT, Q, killactive,"
          "$mod CTRL, Q, forcekillactive,"
        ]
        ++ workspaceBinds;

        # Volume and brightness keys repeat while held, each raising a popup
        # through the OSD client.
        # Volume is capped at 100 percent.
        # The client floors brightness so a full hold cannot black the screen out.
        binde = [
          ", XF86AudioRaiseVolume, exec, ${pkgs.swayosd}/bin/swayosd-client --output-volume raise --max-volume 100"
          ", XF86AudioLowerVolume, exec, ${pkgs.swayosd}/bin/swayosd-client --output-volume lower"
          ", XF86MonBrightnessUp, exec, ${pkgs.swayosd}/bin/swayosd-client --brightness raise"
          ", XF86MonBrightnessDown, exec, ${pkgs.swayosd}/bin/swayosd-client --brightness lower"
        ];

        # Mute and media transport still fire while the session is locked.
        bindl = [
          ", XF86AudioMute, exec, ${pkgs.swayosd}/bin/swayosd-client --output-volume mute-toggle"
          ", XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
          ", XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next"
          ", XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous"
        ];
      };
    };
  };
}
