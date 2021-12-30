{ config, pkgs, lib, modulesPath, inputs, ...}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  modules.locale.timezone = "Europe/Dublin";
}
