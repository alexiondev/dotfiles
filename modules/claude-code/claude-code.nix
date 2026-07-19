{
  config,
  lib,
  ...
}:
# Claude Code — Anthropic's CLI — for the primary user, installed declaratively
# through home-manager. home-manager ships the package and owns ~/.claude; no
# settings are written here, so login and first-run configuration stay
# interactive. Signing in without a browser, as needed over the console or SSH,
# is covered in ./authentication.md.
let
  cfg = config.modules.claude-code;
  user = config.user.name;
in
{
  options.modules.claude-code.enable =
    lib.mkEnableOption "Claude Code, Anthropic's CLI, installed via home-manager";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.claude-code.enable = true;
  };
}
