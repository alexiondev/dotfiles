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
  reservedToolProfiles = [
    "none"
    "read-only"
    "read-only-with-safe-bash"
    "full-tools"
  ];
  subagentsConfig =
    lib.optionalAttrs (cfg.subagents.defaultContext != null) {
      defaultContext = cfg.subagents.defaultContext;
    }
    // lib.optionalAttrs (cfg.subagents.defaultTools != null) {
      defaultTools = cfg.subagents.defaultTools;
    }
    // lib.optionalAttrs (cfg.subagents.maxConcurrent != null) {
      maxConcurrent = cfg.subagents.maxConcurrent;
    }
    // lib.optionalAttrs (cfg.subagents.recentTerminalTtlMs != null) {
      recentTerminalTtlMs = cfg.subagents.recentTerminalTtlMs;
    }
    // lib.optionalAttrs (
      cfg.subagents.ui.enabled != null || cfg.subagents.ui.defaultExpanded != null
    ) {
      ui =
        lib.optionalAttrs (cfg.subagents.ui.enabled != null) {
          enabled = cfg.subagents.ui.enabled;
        }
        // lib.optionalAttrs (cfg.subagents.ui.defaultExpanded != null) {
          defaultExpanded = cfg.subagents.ui.defaultExpanded;
        };
    }
    // lib.optionalAttrs (cfg.subagents.toolProfiles != { }) {
      toolProfiles = cfg.subagents.toolProfiles;
    };
  subagentsJson = (pkgs.formats.json { }).generate "pi-subagents.json" subagentsConfig;
  patchedPi = pkgs.pi-coding-agent.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/pi-flex-spacer.patch
      ./patches/pi-tool-lookup-validation.patch
    ];
  });
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
  options.modules.agents.pi = {
    enable = lib.mkEnableOption ''
      Pi, a terminal coding agent, configured via home-manager'';

    subagents = {
      defaultContext = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [
          "independent"
          "fork"
        ]);
        default = null;
        description = ''
          Default context mode for subagents.
          Left null, the extension keeps its in-code default.
        '';
      };

      defaultTools = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "read-only-with-safe-bash";
        description = ''
          Default tool profile for subagents.
          Left null, the extension keeps its in-code default.
        '';
      };

      maxConcurrent = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        example = 4;
        description = ''
          Maximum number of child processes allowed to run concurrently.
          Left null, the extension keeps its in-code default.
        '';
      };

      recentTerminalTtlMs = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.unsigned;
        default = null;
        example = 600000;
        description = ''
          Milliseconds to retain terminal subagents in the recent work set.
          Zero disables time-based retention.
          Left null, the extension keeps its in-code default.
        '';
      };

      ui = {
        enabled = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = ''
            Whether the extension renders its built-in subagent monitor.
            Left null, the extension keeps its in-code default.
          '';
        };

        defaultExpanded = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = ''
            Whether the built-in subagent monitor starts expanded.
            Left null, the extension keeps its in-code default.
          '';
        };
      };

      toolProfiles = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.activeTools = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Pi tools made available to a child using this profile.";
            };
          }
        );
        default = { };
        example = {
          review = {
            activeTools = [
              "read"
              "grep"
              "find"
              "ls"
            ];
          };
        };
        description = ''
          Custom named tool profiles for subagents.
          The extension's reserved built-in profile names cannot be redefined.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.intersectLists reservedToolProfiles (
          builtins.attrNames cfg.subagents.toolProfiles
        ) == [ ];
        message = "modules.agents.pi.subagents.toolProfiles may not redefine the reserved profiles: ${lib.concatStringsSep ", " reservedToolProfiles}.";
      }
    ];

    home-manager.users.${user} = {
      programs.pi-coding-agent = {
        enable = true;
        package = patchedPi;

        settings = {
          defaultProvider = "openai-codex";
          defaultModel = "gpt-5.5";
          defaultThinkingLevel = "medium";
          theme = "dark";
          enableInstallTelemetry = false;
          enableAnalytics = false;
        };
      };

      home.file =
        {
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
        }
        // lib.optionalAttrs (subagentsConfig != { }) {
          # Declaring any global override makes Nix the owner of the runtime file.
          "${piDir}/subagents.json" = {
            source = subagentsJson;
            force = true;
          };
        };
    };
  };
}
