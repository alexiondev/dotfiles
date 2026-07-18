{ lib, modulesPath, ... }:
# Placeholder hardware profile — regenerated on the target machine at install
# time (`nixos-generate-config` / `disko-install`). Carries only enough for the
# toplevel to evaluate: the host platform and the XPS 13's initrd modules.
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
