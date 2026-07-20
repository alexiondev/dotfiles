{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
# Shared base config carried by every host.
let
  inherit (lib) mkOption types;
  user = config.user;

  passwordSecret = "${user.name}-password";

  # Args to instantiate an extra nixpkgs source on the base platform.
  pinArgs = prev: {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  options.user = {
    name = mkOption {
      type = types.str;
      default = "alexion";
      description = ''
        The primary interactive user this host is built for. Drives both the
        system account and the home-manager user in lockstep.
      '';
    };
    description = mkOption {
      type = types.str;
      default = "Alexion";
      description = "Human-readable description (GECOS field) for the primary user.";
    };
  };

  config = {
    # Reach fresher packages with `unstable.<name>` or pin with `stable.<name>`.
    # chaotic's overlay is added by its own module, not here.
    nixpkgs.overlays = [
      (_final: prev: {
        unstable = import inputs.nixpkgs-unstable (pinArgs prev);
        stable = import inputs.nixpkgs-stable (pinArgs prev);
      })
    ];
    nixpkgs.config.allowUnfree = true;

    # Flakes, so `nixos-rebuild switch` works from the console.
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # chaotic's binary cache, so the CachyOS kernel is fetched rather than
    # compiled. The `extra-` prefix keeps cache.nixos.org alongside it.
    nix.settings.extra-substituters = [ "https://nyx-cache.chaotic.cx/" ];
    nix.settings.extra-trusted-public-keys = [
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
    ];
    environment.systemPackages = [ pkgs.git ];

    # Caps Lock is a second Escape; Shift+Caps Lock still toggles Caps Lock.
    services.xserver.xkb.layout = "us";
    services.xserver.xkb.options = "caps:escape_shifted_capslock";

    # Compile the console keymap from the layout above, so the remap holds on a
    # bare TTY and not only under a graphical session.
    console.useXkbConfig = true;

    # Decryption machinery every host depends on.
    # The identity sits on the encrypted root, which is mounted early enough to
    # satisfy the secret below.
    # Clearing both `sshKeyPaths` defaults keeps the SSH host keys out of the
    # decryption path.
    sops.defaultSopsFile = ../secrets/shared.yaml;
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";
    sops.age.sshKeyPaths = [ ];
    sops.gnupg.sshKeyPaths = [ ];

    # A password set by hand on a running machine otherwise takes precedence.
    # That leaves the declared `hashedPasswordFile` below silently inert.
    # Root has no declared password and is therefore locked.
    # `sudo` from the wheel group is the way in.
    users.mutableUsers = false;

    # Decrypted in an earlier activation stage than ordinary secrets.
    # That is early enough to precede the account that reads it.
    sops.secrets.${passwordSecret}.neededForUsers = true;

    # Primary user, in the wheel group.
    users.users.${user.name} = {
      isNormalUser = true;
      description = user.description;
      extraGroups = [ "wheel" ];
      hashedPasswordFile = config.sops.secrets.${passwordSecret}.path;
    };

    # home-manager as a NixOS module: one `nixos-rebuild switch` builds the
    # system and user environment together, sharing the system's pkgs and
    # installing user packages into the system profile.
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs;
        my = inputs.self.lib;
      };
      users.${user.name} = {
        home.username = user.name;
        home.homeDirectory = "/home/${user.name}";
        home.stateVersion = "26.05";
      };
    };
  };
}
