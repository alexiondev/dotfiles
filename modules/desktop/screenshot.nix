{
  config,
  lib,
  pkgs,
  ...
}:
# Keyboard-driven screenshots that open in satty for annotation, then land in
# both the clipboard and a dated file.
let
  cfg = config.modules.desktop.screenshot;
  user = config.user.name;

  grimblast = "${pkgs.grimblast}/bin/grimblast";
  satty = "${pkgs.satty}/bin/satty";
  wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";

  shotDir = "$HOME/Pictures/Screenshots";

  # satty is the annotation step, and its copy action is set to save as well,
  # so a single keystroke through it lands the shot in both the clipboard and a
  # file.
  capture =
    target:
    pkgs.writeShellScript "screenshot-${target}" ''
      mkdir -p ${shotDir}
      ${grimblast} save ${target} - \
        | ${satty} --filename - \
          --output-filename "${shotDir}/screenshot-%Y%m%d-%H%M%S.png" \
          --copy-command ${wl-copy} \
          --save-after-copy \
          --early-exit \
          --actions-on-enter save-to-clipboard
    '';
in
{
  options.modules.desktop.screenshot.enable = lib.mkEnableOption "screenshots via grimblast and satty";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      # satty is a one-shot annotation surface, so float it rather than letting
      # it claim a tile in the layout.
      wayland.windowManager.hyprland.settings.windowrule = [
        "float, class:^(com\\.gabm\\.satty)$"
      ];

      # Print with plain/Shift/Ctrl for region/window/full.
      # Super+L, the spec's chosen key, is already the hjkl focus and movement
      # bind, so screenshots take the Print key instead.
      wayland.windowManager.hyprland.settings.bind = [
        ", Print, exec, ${capture "area"}"
        "SHIFT, Print, exec, ${capture "active"}"
        "CTRL, Print, exec, ${capture "screen"}"
      ];
    };
  };
}
