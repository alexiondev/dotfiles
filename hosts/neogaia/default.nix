{
  config,
  inputs,
  pkgs,
  ...
}:
# neogaia — Dell XPS 13 9380 laptop.
# Disk layout is in ./disk.nix; `fileSystems` are derived from it, none declared here.
let
  # Read by the daemon at startup, so a re-key has to restart it to take effect.
  sshHostKey = {
    sopsFile = ../../secrets/neogaia.yaml;
    mode = "0400";
    restartUnits = [ "sshd.service" ];
  };
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.dell-xps-13-9380
    ./hardware-configuration.nix
    ./disk.nix
  ];

  system.stateVersion = "26.05";

  # systemd-boot on the EFI system partition.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # Redistributable firmware for the QCA6174 wifi (ath10k blobs).
  # Intel microcode updates follow from this; none declared here.
  hardware.enableRedistributableFirmware = true;

  # RAM-backed swap; no on-disk swap partition.
  zramSwap.enable = true;

  # So wifi can be joined from the console.
  networking.networkmanager.enable = true;

  # So setup can be driven over the network.
  services.openssh.enable = true;

  # This host's SSH identity is restored from secrets.
  # Reimaging the machine therefore keeps its fingerprint, and every client's
  # `known_hosts` entry stays valid.
  # The matching public halves are committed in plaintext, since publishing
  # them is their purpose.
  sops.secrets = {
    ssh-host-ed25519-key = sshHostKey;
    ssh-host-rsa-key = sshHostKey;
  };

  # An empty list is what stops the daemon generating keys of its own.
  services.openssh.hostKeys = [ ];
  services.openssh.extraConfig = ''
    HostKey ${config.sops.secrets.ssh-host-ed25519-key.path}
    HostKey ${config.sops.secrets.ssh-host-rsa-key.path}
  '';

  # fish as the login shell.
  modules.fish.enable = true;
  modules.fish.defaultShell = true;

  modules.tmux.enable = true;
  modules.nvim.enable = true;
  modules.claude-code.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_GB.UTF-8";
}
