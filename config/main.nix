{ config, pkgs, lib, ...}:

{
  imports = [
    ./bash.nix
    ./i3.nix
    ./polybar.nix
    ./vscode.nix
  ];

  programs = {
    home-manager.enable = true;

    alacritty.enable = true;
    rofi.enable = true;
  };
  
  services = {
    picom.enable = true;
  };

  xsession.enable = true;
}
