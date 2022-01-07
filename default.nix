{ config, inputs, lib, pkgs, ... }:

with lib.my;
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ] ++ (findModules ./modules);

  # nix and nixpkgs
  nix = {
    # Enable flakes
    package = pkgs.nixFlakes;
    extraOptions = "experimental-features = nix-command flakes";

    autoOptimiseStore = true;
  };

  boot.loader = {
    efi.canTouchEfiVariables = true;

    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 10;
  };

  modules.shell = {
    aliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
      ls = "ls --color=auto";
      la = "ls --color=auto -a";
      lla = "ls --color=auto -la";
    };
  };

  system.stateVersion = "21.11";
}
