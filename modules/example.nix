{ config, lib, ... }:
# Reference example for the module shape: imported unconditionally, but inert
# until a host sets its `enable` flag.
let
  cfg = config.modules.example;
in
{
  options.modules.example.enable = lib.mkEnableOption "the reference example module";

  config = lib.mkIf cfg.enable {
    environment.etc."skeleton-example".text = "This Module is enabled.\n";
  };
}
