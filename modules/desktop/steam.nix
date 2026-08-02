{
  config,
  lib,
  pkgs,
  ...
}:
# Steam game launcher and runtime integration.
let
  cfg = config.modules.desktop.steam;
in
{
  options.modules.desktop.steam.enable = lib.mkEnableOption "Steam game launcher";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      package = pkgs.steam.override {
        extraEnv.STEAM_FORCE_DESKTOPUI_SCALING = "1.5";
      };
    };

    hardware.steam-hardware.enable = true;
  };
}
