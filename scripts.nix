{ pkgs, ...}:

{
  rofi_run = pkgs.writeShellScriptBin "rofi_run" ''
    ANS="$(rofi -sep "|" -dmenu -i -p 'System' -width 20 \
    -hide-scrollbar -line-padding 4 -padding 20 \
    -lines 3 <<< "Logout|Reboot|Shutdown")"

    case "$ANS" in
        *Reboot) systemctl reboot ;;
        *Shutdown) systemctl -i poweroff ;;
        *Logout) i3-msg exit;;
    esac
  '';
}