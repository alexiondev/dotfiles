{
  config,
  lib,
  pkgs,
  ...
}:
# Pi, a terminal coding agent, for the primary user, configured through
# home-manager, which ships the package and manages ~/.pi/agent.
# The login credential is left unmanaged, so it survives rebuilds.
let
  cfg = config.modules.agents.pi;
  user = config.user.name;
  piDir = "${config.users.users.${user}.home}/.pi/agent";
  herdrPiIntegration = pkgs.stdenvNoCC.mkDerivation {
    name = "herdr-pi-integration";
    nativeBuildInputs = [ pkgs.herdr ];
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $TMPDIR/home/.pi/agent/extensions
      HOME=$TMPDIR/home herdr integration install pi
      mkdir -p $out
      cp $TMPDIR/home/.pi/agent/extensions/herdr-agent-state.ts $out/herdr-agent-state.ts
    '';
  };
  piExtensions = pkgs.stdenvNoCC.mkDerivation {
    name = "pi-extensions";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out
      cp -R ${./extensions}/. $out/
      cp ${herdrPiIntegration}/herdr-agent-state.ts $out/herdr-agent-state.ts
    '';
  };
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
          defaultModel = "gpt-5.6-sol";
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
          source = piExtensions;
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
