{ config, lib, options, pkgs, ... }:

with lib.my;
let cfg = config.modules.theme;
in {
  config = lib.mkIf (cfg.active == "dracula") {
    # modules.theme.fonts = ["font-awesome" "hack-font"];
    modules.theme.fonts = with pkgs; [
      font-awesome
      hack-font
    ];
  };
}