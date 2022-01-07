{ config, lib, options, pkgs, ... }:

with lib.my;
with lib.types;
let cfg = config.modules.theme;
in
{
  imports = findModules ./.;

  options.modules.theme = with lib.types; {
    active = mkOpt (nullOr str) null;

    fonts = {
      packages = mkOpt (listOf package) [
        pkgs.fira-code
        pkgs.fira-code-symbols
        pkgs.font-awesome-ttf
      ];

      default = {
        emoji = mkOpt (listOf str) [ ];
        monospace = mkOpt (listOf str) [ "Fira Code" ];
        sansSerif = mkOpt (listOf str) [ "Fira Sans" ];
        serif = mkOpt (listOf str) [ ];
      };
    };
  };

  config = lib.mkIf (cfg.active != null) {
    fonts = {
      fonts = cfg.fonts.packages;
      fontconfig = {
        enable = true;
        defaultFonts = cfg.fonts.default;
      };
    };
  };
}
