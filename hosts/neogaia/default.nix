{ config, pkgs, lib, modulesPath, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  modules = {
    cli = {
      git.enable = true;
      xclip.enable = true;
    };
    desktop = {
      browsers.firefox.enable = true;
      browsers.chromium.enable = true;
      communication.discord.enable = true;
      media.spotify.enable = true;
      term.alacritty.enable = true;
      util = {
        brightness.enable = true;
        compositor.enable = true;
        polybar.enable = true;
        redshift.enable = true;
        rofi.enable = true;
      };
      i3.enable = true;
      startx.enable = true;
    };
    editors = {
      nvim.enable = true;
      vscode.enable = true;
    };
    hardware = {
      sound.enable = true;
      touchpad.enable = true;
    };
    theme.active = "dracula";
  };
}
