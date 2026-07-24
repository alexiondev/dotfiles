{
  config,
  lib,
  ...
}:
# Pi, a terminal coding agent, for the primary user, configured through
# home-manager, which ships the package and manages ~/.pi/agent.
# The login credential is left unmanaged, so it survives rebuilds.
let
  cfg = config.modules.agents.pi;
  user = config.user.name;
in
{
  options.modules.agents.pi.enable = lib.mkEnableOption ''
    Pi, a terminal coding agent, configured via home-manager'';

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.pi-coding-agent = {
      enable = true;

      settings = {
        defaultProvider = "anthropic";
        # Pi's catalogue id for Opus.
        defaultModel = "claude-opus-4-8";
        enableAnalytics = false;
      };
    };
  };
}
