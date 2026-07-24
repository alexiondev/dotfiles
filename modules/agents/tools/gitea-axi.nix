{
  config,
  lib,
  inputs,
  ...
}:
# gitea-axi for the primary user, installed through its own home-manager module.
let
  cfg = config.modules.agents.tools.gitea-axi;
  user = config.user.name;
in
{
  options.modules.agents.tools.gitea-axi.enable =
    lib.mkEnableOption "gitea-axi, an agent-ergonomic CLI for Gitea issues and pull requests";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [ inputs.gitea-axi.homeModules.default ];
    home-manager.users.${user}.programs.gitea-axi.enable = true;
  };
}
