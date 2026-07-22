{
  config,
  lib,
  pkgs,
  ...
}:
# Clipboard history: cliphist records every copy, picked back through rofi.
let
  cfg = config.modules.desktop.clipboard;
  user = config.user.name;

  cliphist = "${pkgs.cliphist}/bin/cliphist";
  rofi = "${pkgs.rofi}/bin/rofi";
  wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";

  # The picker reuses the themed rofi, so history looks like every other menu
  # the launcher drives.
  # decode is needed because list emits id-prefixed lines rather than the copied
  # bytes, so the chosen id has to be resolved back before it can be re-copied.
  picker = pkgs.writeShellScript "clipboard-picker" ''
    ${cliphist} list \
      | ${rofi} -dmenu -i -p Clipboard \
      | ${cliphist} decode \
      | ${wl-copy}
  '';
in
{
  options.modules.desktop.clipboard.enable = lib.mkEnableOption "cliphist clipboard history";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      # wl-copy and wl-paste on PATH, so the shell can pipe into and out of the
      # clipboard.
      # The watchers and picker above reach wl-clipboard by store path, so this
      # is for interactive use alone.
      home.packages = [ pkgs.wl-clipboard ];

      # Two watchers record text and images to history, bound to the graphical
      # session so uwsm starts and stops them with it.
      services.cliphist.enable = true;

      # $mod is defined by the compositor config these binds share.
      wayland.windowManager.hyprland.settings.bind = [
        "$mod SHIFT, V, exec, ${picker}"
      ];
    };
  };
}
