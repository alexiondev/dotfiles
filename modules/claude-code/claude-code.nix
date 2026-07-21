{
  config,
  lib,
  pkgs,
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
  options.modules.claude-code.enable = lib.mkEnableOption ''
    Claude Code, Anthropic's CLI, configured via home-manager.

    Enabling this also widens sudo's credential cache, keying it per user rather
    than per terminal and holding it for 60 minutes, so that a single
    authentication covers commands the agent issues. No command is made
    passwordless, but any process running as the primary user can spend the
    cached credential while it lasts. Suitable for a single-user machine'';

  config = lib.mkIf cfg.enable {
    # Keying sudo's credential cache per user rather than per terminal lets one
    # authentication cover commands issued by processes holding no terminal of
    # their own. Any process running as this user can spend that credential
    # until it lapses, so this suits a single-user machine.
    security.sudo.extraConfig = ''
      Defaults timestamp_type=global
      Defaults timestamp_timeout=60
    '';

    home-manager.users.${user} = {
      # jq parses the tool input handed to the sudo guard hook.
      home.packages = [ pkgs.jq ];

      programs.claude-code = {
        enable = true;

        # Global agent instructions, rendered to ~/.claude/CLAUDE.md.
        context = ./CLAUDE.md;

        # One directory per skill, symlinked under ~/.claude/skills.
        skills = ./skills;

        # Installed under ~/.claude/hooks, referenced by the settings below.
        hooks."attention-bell.sh" = builtins.readFile ./hooks/attention-bell.sh;
        hooks."agent-sudo-guard.sh" = builtins.readFile ./hooks/agent-sudo-guard.sh;

        settings = {
          model = "opus";
          hooks = {
            Stop = bellHook;
            Notification = bellHook;
            PreToolUse = [
              {
                matcher = "Bash";
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/agent-sudo-guard.sh";
                    timeout = 10;
                  }
                ];
              }
            ];
          };
        };
      };
    };
  };
}
