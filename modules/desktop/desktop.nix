{ config, lib, ... }:
# The desktop aggregator: one flag brings up the whole graphical session.
let
  cfg = config.modules.desktop;
in
{
  options.modules.desktop.enable = lib.mkEnableOption "the keyboard-driven Hyprland desktop";

  # Each piece is turned on at default priority, so a host can still override
  # any one of them while the single flag above enables the whole desktop.
  config = lib.mkIf cfg.enable {
    modules.desktop.clipboard.enable = lib.mkDefault true;
    modules.desktop.firefox.enable = lib.mkDefault true;
    modules.desktop.hyprland.enable = lib.mkDefault true;
    modules.desktop.hyprland.hyprlock.enable = lib.mkDefault true;
    modules.desktop.hyprland.hypridle.enable = lib.mkDefault true;
    modules.desktop.login.enable = lib.mkDefault true;
    modules.desktop.mako.enable = lib.mkDefault true;
    modules.desktop.portals.enable = lib.mkDefault true;
    modules.desktop.recording.enable = lib.mkDefault true;
    modules.desktop.rofi.enable = lib.mkDefault true;
    modules.desktop.screenshot.enable = lib.mkDefault true;
    modules.desktop.terminal.enable = lib.mkDefault true;
    modules.desktop.userdirs.enable = lib.mkDefault true;
    modules.desktop.theming.enable = lib.mkDefault true;
    modules.desktop.waybar.enable = lib.mkDefault true;
    modules.desktop.audio.enable = lib.mkDefault true;
  };
}
