{
  config,
  lib,
  ...
}:
# git for the primary user, configured through home-manager.
let
  cfg = config.modules.git;
  user = config.user.name;
in
{
  options.modules.git.enable =
    lib.mkEnableOption "git for the primary user, carrying the operator's commit identity";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.git = {
      enable = true;

      # Git will not guess a name and address from the login and hostname.
      # Without these a commit fails outright with `Author identity unknown`.
      settings.user.name = "alexion";
      settings.user.email = "contact@alexion.dev";
    };
  };
}
