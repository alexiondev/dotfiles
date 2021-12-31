{ config, lib, pkgs, ... }:

with lib.my;
let cfg = config.modules.networking;
in {
  options.modules.networking = {
    enable = mkBool true;
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.enable = true;
  };
}