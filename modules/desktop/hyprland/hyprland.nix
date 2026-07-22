{
  config,
  lib,
  pkgs,
  ...
}:
# The Hyprland compositor, sourced from nixpkgs.
let
  cfg = config.modules.desktop.hyprland;
  user = config.user.name;

  # Numbered-workspace switch and move for 1..9, the operator's i3 muscle memory.
  workspaceBinds = lib.concatMap (n: [
    "$mod, ${toString n}, workspace, ${toString n}"
    "$mod SHIFT, ${toString n}, movetoworkspace, ${toString n}"
  ]) (lib.range 1 9);
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

        input = {
          kb_layout = "us";
          # Caps is a second Escape.
          # Shift+Caps still toggles a real CapsLock.
          kb_options = "caps:escape_shifted_capslock";
          # Snappy: a short delay before repeat begins, then a fast repeat rate.
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
          "$mod SHIFT, Q, killactive,"
          "$mod CTRL, Q, forcekillactive,"
        ]
        ++ workspaceBinds;
      };
    };
  };
}
