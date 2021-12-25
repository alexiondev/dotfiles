{ config, pkgs, lib, ...}:

{
  imports = [
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

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;

      desktop     = "$HOME/.desktop";
      documents   = "$HOME/doc";
      download    = "$HOME/dwn";
      music       = "$HOME/.hideme";
      pictures    = "$HOME/pic";
      publicShare = "$HOME/.hideme";
      templates   = "$HOME/.hideme";
      videos      = "$HOME/.hideme";
    };
  };

  xsession.enable = true;
}
