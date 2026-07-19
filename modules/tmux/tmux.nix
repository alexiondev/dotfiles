{
  config,
  lib,
  ...
}:
# tmux for the primary user, configured through home-manager. Settings without a
# home-manager option are read from ./extra.conf.
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
      baseIndex = 1;
      clock24 = true;
      escapeTime = 10; # short Esc delay so exiting insert mode in nvim isn't laggy.
      historyLimit = 10000;
      terminal = "tmux-256color";

      extraConfig = builtins.readFile ./extra.conf;
    };
  };
}
