{ config, lib, ... }:
# The Auto-loader reference example. Every real Module copies this shape: it is
# imported unconditionally but its body stays inert until a Host sets the
# `enable` flag, so each Host reads as a checklist of `enable = true` lines.
let
  cfg = config.modules.example;
in
{
  options.modules.example.enable = lib.mkEnableOption "the Auto-loader reference example Module";

  config = lib.mkIf cfg.enable {
    environment.etc."skeleton-example".text = "This Module is enabled.\n";
  };
}
