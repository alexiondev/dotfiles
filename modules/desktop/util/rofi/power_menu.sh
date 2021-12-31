rofi_command="rofi -sep | -dmenu -i -p 'Power Menu' -selected-row 2"

# Options
poweroff="  Shutdown"
reboot="  Reboot"
logout="  Logout"
lock="  Lock"

options="$logout|$reboot|$poweroff"

ANS = "$(rofi -sep "|" -dmenu -i -p 'System' \
          -hide-scrollbar -lines 4 <<< $options)"
          
case $ANS in
  $poweroff)
    systemctl poweroff
    ;;
  $reboot)
    systemctl reboot
    ;;
  $logout)
    i3-msg exit
    ;;
esac