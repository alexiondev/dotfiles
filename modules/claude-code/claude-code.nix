{
  config,
  lib,
  ...
}:
# Claude Code — Anthropic's CLI — for the primary user, configured declaratively
# through home-manager. home-manager ships the package and manages ~/.claude:
# the global agent instructions (./CLAUDE.md), the skills tree (./skills), the
# attention-bell hook (./hooks), and settings.json (the model and the hook
# wiring). Login credentials are left unmanaged so they survive rebuilds;
# signing in without a browser, as needed over the console or SSH, is covered in
# ./authentication.md.
let
  cfg = config.modules.claude-code;
  user = config.user.name;

  # Rings the terminal bell so tmux flags the background pane; wired to both the
  # end of a turn and attention notifications below.
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

      # One directory per skill, each carrying its SKILL.md, symlinked under
      # ~/.claude/skills.
      skills = ./skills;

      # Installed executable at ~/.claude/hooks/attention-bell.sh, where the
      # settings hooks reference it.
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
