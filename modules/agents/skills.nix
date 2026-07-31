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
  # wiki reads the personal Obsidian vault, and consume mines a source into it.
  # grill interviews the operator relentlessly to resolve a plan before building.
  # design-skill drafts and audits Agent Skills for structural predictability.
  # wayfinder, research, and prototype guide work from exploration through validation.
  skills = with inputs.skills.packages.${pkgs.stdenv.hostPlatform.system}; [
    wiki
    consume
    grill
    design-skill
    wayfinder
    research
    prototype
  ];
in
{
  home-manager.sharedModules = [ inputs.skills.homeModules.default ];
  home-manager.users.${user}.programs.agents.skills = skills;
}
