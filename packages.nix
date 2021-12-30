{ pkgs, ...}:

let
    scripts = import ./scripts.nix { inherit pkgs; };
in {
  home.packages = with pkgs; [
    alacritty
    discord
    light
    nix-index
    pavucontrol
    playerctl
    pulseaudio
    rofi
    spotify
    xclip
    xdotool

    scripts.rofi_run

    font-awesome
    hack-font
  ];
}