{
  config,
  lib,
  pkgs,
  ...
}:
# Nord theming for the graphical layer, driven from one base16 scheme by Stylix.
let
  cfg = config.modules.desktop.theming;
  user = config.user.name;

  # A single static Nord wallpaper, drawn as a vertical gradient across the
  # Polar Night shades so it needs no committed binary and no network fetch.
  wallpaper = pkgs.runCommand "nord-wallpaper.png" { } ''
    ${pkgs.imagemagick}/bin/magick \
      -size 2560x1440 gradient:'#2E3440'-'#3B4252' \
      "$out"
  '';
in
{
  options.modules.desktop.theming.enable =
    lib.mkEnableOption "Nord theming of the graphical layer via Stylix";

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;

      # Nord is a dark scheme.
      # The polarity steers Stylix's contrast choices.
      polarity = "dark";
      base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";

      image = wallpaper;

      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };

      fonts.monospace = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };

      # fish is also installed at system level, so its theming has a target
      # here of its own.
      targets.fish.enable = false;
    };

    home-manager.users.${user} = {
      # Stylix drives the cursor through home-manager's pointer-cursor config,
      # whose generation must be switched on explicitly.
      home.pointerCursor.enable = true;

      # nvim, tmux, and fish are configured through home-manager and keep their
      # own hand-written themes, so their Stylix targets stay off.
      stylix.targets = {
        fish.enable = false;
        tmux.enable = false;
        nixvim.enable = false;
      };
    };
  };
}
