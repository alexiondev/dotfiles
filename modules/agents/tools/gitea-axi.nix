{
  config,
  lib,
  inputs,
  ...
}:
# gitea-axi for the primary user, installed through its own home-manager module.
# That module also declares the Claude Code context when that harness is
# enabled on the host; enabling this alone installs the CLI and nothing else.
let
  cfg = config.modules.gitea-axi;
  user = config.user.name;
in
{
  options.modules.gitea-axi.enable =
    lib.mkEnableOption "gitea-axi, an agent-ergonomic CLI for Gitea issues and pull requests";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [ inputs.gitea-axi.homeModules.default ];
    home-manager.users.${user}.programs.gitea-axi.enable = true;
  };
}
