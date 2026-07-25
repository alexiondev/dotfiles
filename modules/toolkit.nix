{ config, lib, ... }:
# The baseline interactive toolset as one deliberate bundle.
let
  cfg = config.modules.toolkit;
in
{
  options.modules.toolkit.enable =
    lib.mkEnableOption "the baseline interactive environment — fish, tmux, nvim, git, and direnv — as one unit";

  # Each piece is turned on at default priority, so a host can still override any one of them.
  config = lib.mkIf cfg.enable {
    modules.fish.enable = lib.mkDefault true;
    # fish is also the login shell, so the bundled environment is what a shell drops into.
    modules.fish.defaultShell = lib.mkDefault true;
    modules.tmux.enable = lib.mkDefault true;
    modules.nvim.enable = lib.mkDefault true;
    modules.git.enable = lib.mkDefault true;
    modules.direnv.enable = lib.mkDefault true;
  };
}
