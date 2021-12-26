{ config, pkgs, lib, modulesPath, inputs, ...}:

{
  imports = [
    ./hardware-configuration.nix
  ];
}
