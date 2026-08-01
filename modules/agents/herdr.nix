{
  config,
  lib,
  pkgs,
  ...
}:
# Herdr, a terminal multiplexer for coding agents.
let
  cfg = config.modules.agents.herdr;
  user = config.user.name;
in
{
  options.modules.agents.herdr.enable = lib.mkEnableOption "Herdr, a terminal multiplexer for coding agents";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      home.packages = [ pkgs.herdr ];

      xdg.configFile."herdr/config.toml".text = ''
        [keys]
        prefix = "ctrl+space"
        detach = "prefix+d"
        reload_config = "prefix+r"
        new_workspace = "prefix+c"
        new_tab = "prefix+shift+c"
        rename_workspace = "prefix+comma"
        rename_tab = "prefix+<"
        split_vertical = "prefix+backslash"
        split_horizontal = "prefix+minus"
        switch_workspace = "prefix+1..9"
        switch_tab = "prefix+shift+1..9"
        focus_pane_left = "prefix+h"
        focus_pane_down = "prefix+j"
        focus_pane_up = "prefix+k"
        focus_pane_right = "prefix+l"

        [ui]
        prompt_new_tab_name = false
      '';
    };
  };
}
