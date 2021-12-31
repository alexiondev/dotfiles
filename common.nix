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

  system.stateVersion = "21.11";
}