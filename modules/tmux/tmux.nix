{
  config,
  lib,
  ...
}:
# tmux for the primary user, configured natively through home-manager. The
# settings home-manager exposes as options are set here; every setting it has
# no option for is read verbatim from ./extra.conf. No tmux plugin manager is
# used.
let
  cfg = config.modules.tmux;
  user = config.user.name;
in
{
  options.modules.tmux.enable = lib.mkEnableOption "tmux, configured via home-manager";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.tmux = {
      enable = true;

      prefix = "C-Space";
      keyMode = "vi";
      mouse = true;
      baseIndex = 1; # windows and panes count from 1.
      clock24 = true; # 24-hour clock in the clock-mode overlay.
      escapeTime = 10; # short Esc delay so exiting insert mode in nvim isn't laggy.
      historyLimit = 10000;
      terminal = "tmux-256color";

      extraConfig = builtins.readFile ./extra.conf;
    };
  };
}
