{ config, inputs, ... }:
# Global agent skills, placed under the skills directory so they are active in
# every project.
let
  user = config.user.name;

  # The skills installed globally, as derivations from the skills flake.
  skills = [ ];
in
{
  home-manager.sharedModules = [ inputs.skills.homeModules.default ];
  home-manager.users.${user}.programs.agents.skills = skills;
}
