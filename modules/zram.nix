{ config, lib, ... }:
# A toggle for RAM-backed swap. A Host that has no on-disk swap partition (like
# neogaia, whose disko layout deliberately omits one) enables this to get a
# compressed zram device instead.
let
  cfg = config.modules.zram;
in
{
  options.modules.zram.enable = lib.mkEnableOption "zram-backed compressed swap";

  config = lib.mkIf cfg.enable {
    zramSwap.enable = true;
  };
}
