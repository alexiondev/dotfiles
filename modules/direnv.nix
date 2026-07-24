{
  config,
  lib,
  ...
}:
# direnv for the primary user, configured through home-manager.
let
  cfg = config.modules.direnv;
  user = config.user.name;
in
{
  options.modules.direnv.enable =
    lib.mkEnableOption "direnv for the primary user, with nix-direnv shell caching";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.direnv = {
      enable = true;

      # nix-direnv caches the evaluated shell so re-entering a directory is instant
      # instead of re-running `nix develop`, and adds the `use flake` stdlib helper.
      nix-direnv.enable = true;
    };
  };
}
