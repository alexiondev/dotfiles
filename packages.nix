{ pkgs, ...}:

let
    scripts = import ./scripts.nix { inherit pkgs; };
in {
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

    scripts.rofi_run
  ];
}