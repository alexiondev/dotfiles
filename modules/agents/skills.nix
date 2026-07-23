{ config, inputs, ... }:
# Global agent skills from the skills flake, placed under the agent harness's
# skills directory so they are active in every project. The flake's home-manager
# module self-gates on the harness being enabled and installs nothing for an
# empty selection, so a host without one carries no skills either way.
#
# Unlike every other module, this one declares no `enable` flag and wires
# unconditionally, by design.
# The flake's self-gating above already makes it inert where the harness is
# absent, so a gate would guard nothing.
let
  user = config.user.name;

  # The skills installed globally, as derivations from the skills flake.
  skills = [ ];
in
{
  home-manager.sharedModules = [ inputs.skills.homeModules.default ];
  home-manager.users.${user}.programs.agents.skills = skills;
}
