{
  config,
  lib,
  ...
}:
# Claude Code for the primary user, configured through home-manager, which ships
# the package and manages ~/.claude. Login credentials are left unmanaged so they
# survive rebuilds.
let
  cfg = config.modules.claude-code;
  user = config.user.name;

  # Rings the terminal bell so tmux flags the background pane.
  bellHook = [
    {
      hooks = [
        {
          type = "command";
          command = "~/.claude/hooks/attention-bell.sh";
        }
      ];
    }
  ];
in
{
  options.modules.claude-code.enable = lib.mkEnableOption "Claude Code, Anthropic's CLI, configured via home-manager";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.claude-code = {
      enable = true;

      # Global agent instructions, rendered to ~/.claude/CLAUDE.md.
      context = ./CLAUDE.md;

      # One directory per skill, symlinked under ~/.claude/skills.
      skills = ./skills;

      # Installed at ~/.claude/hooks/attention-bell.sh, referenced by the settings below.
      hooks."attention-bell.sh" = builtins.readFile ./hooks/attention-bell.sh;

      settings = {
        model = "opus";
        hooks = {
          Stop = bellHook;
          Notification = bellHook;
          SessionStart = [
            {
              matcher = "";
              hooks = [
                {
                  type = "command";
                  command = "gitea-axi";
                  timeout = 10;
                }
              ];
            }
          ];
        };
      };
    };
  };
}
