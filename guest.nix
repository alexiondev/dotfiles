{
  my,
  inputs,
  lib,
  ...
}:
# The guest-base: the slim foundation every nested guest's interior stands on.
# It imports the full modules tree so any module is available to enable inside a
# guest, and stands on the same shared base a host does.
{
  imports = my.collectNixFiles (inputs.self + "/modules") ++ [
    (inputs.self + "/base.nix")

    # The modules tree reaches for these option namespaces, so they must be
    # declared for the tree to evaluate even where a guest leaves them off.
    inputs.sops-nix.nixosModules.sops
    inputs.stylix.nixosModules.stylix
  ];

  # A nested container has no per-host `default.nix` to pin its release.
  system.stateVersion = "26.05";

  # The baseline toolset and SSH access, so any guest shelled into is a workable
  # environment without per-guest wiring.
  modules.toolkit.enable = lib.mkDefault true;
  modules.ssh.enable = lib.mkDefault true;

  # A guest carries no host identity, so it presents a self-generated host key
  # rather than restoring one from secrets.
  modules.ssh.hostKeys.restore = lib.mkDefault false;
}
