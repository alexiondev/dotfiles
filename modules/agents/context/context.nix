{
  config,
  lib,
  ...
}:
# Shared global instructions for agent harnesses.
let
  user = config.user.name;
  context = builtins.readFile ./AGENTS.md;
in
{
  config = lib.mkMerge [
    (lib.mkIf config.modules.agents.claude-code.enable {
      home-manager.users.${user}.programs.claude-code.context = context;
    })

    (lib.mkIf config.modules.agents.pi.enable {
      home-manager.users.${user}.programs.pi-coding-agent.context = context;
    })
  ];
}
