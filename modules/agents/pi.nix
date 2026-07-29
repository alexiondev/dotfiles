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
        defaultProvider = "openai";
        # Pi's catalogue id for OpenAI's Codex model, served by the ChatGPT subscription.
        defaultModel = "gpt-5.3-codex";
        enableAnalytics = false;
      };
    };
  };
}
