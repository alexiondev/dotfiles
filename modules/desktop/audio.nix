{ config, lib, ... }:
# PipeWire as the desktop audio server.
let
  cfg = config.modules.desktop.audio;
in
{
  options.modules.desktop.audio.enable = lib.mkEnableOption "the PipeWire audio server";

  config = lib.mkIf cfg.enable {
    # Realtime scheduling for the audio threads, so playback survives load.
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
  };
}
