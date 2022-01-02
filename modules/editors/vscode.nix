{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.editors.vscode;
in {
  options.modules.editors.vscode = {
    enable = mkBool false;
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.users.${config.user.name}.programs.vscode = {
      enable = true;
      userSettings = let
        fonts = config.modules.theme.fonts.default.monospace ++ fa;
        fa = ["Font Awesome 5 Brands" "Font Awesome 5 Free" "Font Awesome 5 Free Solid"];
      in {
        "editor.fontFamily" = lib.concatStringsSep "," (map (x: "'${x}'") fonts);
        "editor.fontLigatures" = true;
      };
    };
  };
}