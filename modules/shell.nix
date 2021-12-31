{ config, lib, options, pkgs, ... }:

with lib.my;
let cfg = config.modules.shell;
in {
  options.modules.shell = with lib.types; {
    active = mkStr "bash";

    aliases = mkOpt attrs {
      ".."  = "cd ..";
      "..." = "cd ../..";

      ls    = "ls --color=auto";
      la    = "ls --color=auto -a";
      lla   = "ls --color=auto -la";
    };

    variables = mkOpt attrs {};
  };

  config = lib.mkIf (cfg.active != null) {
    home-manager.users.${config.user.name}.programs.${cfg.active}.enable = true;

    environment.shellAliases = cfg.aliases;
    environment.sessionVariables = cfg.variables;
  };
}