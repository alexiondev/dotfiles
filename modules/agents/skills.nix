{
  config,
  inputs,
  pkgs,
  ...
}:
# Global agent skills, placed under the skills directory so they are active in
# every project.
let
  user = config.user.name;

  # The skills installed globally, as derivations from the skills flake.
  # grill interviews the operator relentlessly to resolve a plan before building.
  # design-skill drafts and audits Agent Skills for structural predictability.
  # wayfinder, research, prototype, and slice guide work from exploration through implementation tickets.
  skills = with inputs.skills.packages.${pkgs.stdenv.hostPlatform.system}; [
    grill
    design-skill
    wayfinder
    research
    prototype
    slice
  ];
in
{
  home-manager.sharedModules = [ inputs.skills.homeModules.default ];
  home-manager.users.${user}.programs.agents.skills = skills;
}
