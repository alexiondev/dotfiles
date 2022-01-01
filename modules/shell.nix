{ config, lib, options, pkgs, ... }:

with lib.my;
let cfg = config.modules.shell;
in {
  options.modules.shell = with lib.types; {
    active = mkStr "bash";

    aliases = mkOpt (attrsOf (either str path)) {};

    variables = mkOpt attrs {};
  };

  config = lib.mkIf (cfg.active != null) {
    home-manager.users.${config.user.name}.programs.${cfg.active}.enable = true;

    environment.shellAliases = cfg.aliases;
    environment.sessionVariables = cfg.variables;
  };
}