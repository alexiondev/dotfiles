{ inputs, config, lib, pkgs, ... }:
let
  inherit (lib) mkDefault;
in {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];
  # TODO: Add personal modules

  # nix and nixpkgs
  nix = {
    # Enable flakes
    package = pkgs.nixFlakes;
    extraOptions = "experimental-features = nix-command flakes";

    autoOptimiseStore = true;
  };

  nixpkgs.config.allowUnfree = true;

  boot.loader = {
    efi.canTouchEfiVariables = true;

    systemd-boot.enable = mkDefault true;
    systemd-boot.configurationLimit = 10;
  };

  system.stateVersion = "21.11";
}