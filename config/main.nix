{ config, pkgs, lib, ...}:

{
  imports = [
    ./i3.nix
    ./vscode.nix
  ];

  programs = {
    home-manager.enable = true;

    alacritty.enable = true;
    rofi.enable = true;
  };
  
  xsession.enable = true;
}
