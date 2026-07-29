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
  piDir = "${config.users.users.${user}.home}/.pi/agent";
in
{
  options.modules.agents.pi.enable = lib.mkEnableOption ''
    Pi, a terminal coding agent, configured via home-manager'';

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.pi-coding-agent = {
        enable = true;

        settings = {
          defaultProvider = "openai-codex";
          defaultModel = "gpt-5.5";
          defaultThinkingLevel = "medium";
          theme = "dark";
          enableInstallTelemetry = false;
          enableAnalytics = false;
        };
      };

      home.file = {
        # The first declarative rollout replaces the interactive settings file.
        # Login state stays in auth.json, which this module does not manage.
        "${piDir}/settings.json".force = true;

        "${piDir}/extensions" = {
          source = ./extensions;
          recursive = true;
        };

        "${piDir}/prompts" = {
          source = ./prompts;
          recursive = true;
        };
      };
    };
  };
}
