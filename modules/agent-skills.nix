{ config, inputs, ... }:
# Global agent skills from the skills flake, placed under the agent harness's
# skills directory so they are active in every project. The flake's home-manager
# module self-gates on the harness being enabled and installs nothing for an
# empty selection, so a host without one carries no skills either way.
let
  user = config.user.name;

  # The skills installed globally, as derivations from the skills flake.
  skills = [ ];
in
{
  home-manager.sharedModules = [ inputs.skills.homeModules.default ];
  home-manager.users.${user}.programs.agents.skills = skills;
}
