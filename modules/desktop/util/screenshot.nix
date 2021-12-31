{ config, lib, pkgs, ... }:

with lib.my;
with lib.types;
let cfg = config.modules.desktop.util.screenshot;
in {
  options.modules.desktop.util.screenshot =
  let file = "pic/$(date +'screen_%Y%m%d-%H%M%S.png')";
      clip = "xclip -selection c -t image/png";
      window = "xdotool getactivewindow";
  in {
    select = mkStr "maim -s | tee ${file} | ${clip}";
    window = mkStr "maim -i ${window} | tee ${file} | ${clip}";
    full   = mkStr "maim | tee ${file} | ${clip}";
  };

  config = {
    home-manager.users.${config.user.name}.home.packages = with pkgs; [
      maim
      xdotool
    ];
  };
}