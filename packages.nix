{ pkgs, ...}:

{
  home.packages = with pkgs; [
    alacritty
    light
    nix-index
    playerctl
    pulseaudio
    rofi
    spotify
    xclip
    xdotool
  ];
}