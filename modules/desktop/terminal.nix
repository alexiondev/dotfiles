{
  config,
  lib,
  ...
}:
# Ghostty as the desktop terminal.
let
  cfg = config.modules.desktop.terminal;
  user = config.user.name;
in
{
  options.modules.desktop.terminal.enable = lib.mkEnableOption "Ghostty as the desktop terminal";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.ghostty = {
      enable = true;

      # Reuse a single process, so each window after the first opens instantly
      # instead of paying a fresh GTK startup.
      settings.gtk-single-instance = true;
    };
  };
}
