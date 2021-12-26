{ config, lib, mylib, options, ...}:

let cfg = config.modules.networking;
in {
  options.modules.networking = {
    enable = mylib.mkBool true;
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.enable = true;
  };
}