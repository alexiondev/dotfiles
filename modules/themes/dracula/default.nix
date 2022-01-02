{ config, lib, options, pkgs, ... }:

with lib.my;
let cfg = config.modules.theme;
in {
  config = lib.mkIf (cfg.active == "dracula") {};
}