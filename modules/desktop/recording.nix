{
  config,
  lib,
  pkgs,
  ...
}:
# Keybound screen recording: pick a region, then toggle a video-only capture.
let
  cfg = config.modules.desktop.recording;
  user = config.user.name;

  slurp = "${pkgs.slurp}/bin/slurp";
  wf-recorder = "${pkgs.wf-recorder}/bin/wf-recorder";
  notify-send = "${pkgs.libnotify}/bin/notify-send";
  pgrep = "${pkgs.procps}/bin/pgrep";
  pkill = "${pkgs.procps}/bin/pkill";
  date = "${pkgs.coreutils}/bin/date";
  mkdir = "${pkgs.coreutils}/bin/mkdir";
  xdgUserDir = "${pkgs.xdg-user-dirs}/bin/xdg-user-dir";

  # A single key both starts and stops.
  # A running wf-recorder is stopped with SIGINT so it finalises the file.
  # Otherwise slurp picks a region and wf-recorder runs in the foreground until
  # that stop arrives, so this instance lives for the whole recording and then
  # reports it saved.
  # No -a means no audio is captured.
  toggle = pkgs.writeShellScript "screen-record-toggle" ''
    if ${pgrep} -x wf-recorder >/dev/null; then
      ${pkill} -INT -x wf-recorder
      exit 0
    fi

    region=$(${slurp}) || exit 0
    dir="$(${xdgUserDir} VIDEOS)/Recordings"
    ${mkdir} -p "$dir"
    file="$dir/recording-$(${date} +%Y%m%d-%H%M%S).mp4"

    ${notify-send} -a "Screen recording" "Recording started" "Region capture, no audio."
    ${wf-recorder} -g "$region" -f "$file"
    ${notify-send} -a "Screen recording" "Recording saved" "$file"
  '';
in
{
  options.modules.desktop.recording.enable = lib.mkEnableOption "wf-recorder screen recording";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      # $mod is defined by the compositor config these binds share.
      wayland.windowManager.hyprland.settings.bind = [
        "$mod SHIFT, R, exec, ${toggle}"
      ];
    };
  };
}
