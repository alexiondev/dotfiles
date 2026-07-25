{
  config,
  lib,
  inputs,
  ...
}:
# The shared foundation both the host base and the guest-base build on: the
# primary user, home-manager, and the fresher/pinned package overlays.
let
  inherit (lib) mkOption types;
  user = config.user;

  # Args to instantiate an extra nixpkgs source on the base platform.
  pinArgs = prev: {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  options.user = {
    name = mkOption {
      type = types.str;
      default = "alexion";
      description = ''
        The primary interactive user this system is built for. Drives both the
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
    nixpkgs.overlays = [
      (_final: prev: {
        unstable = import inputs.nixpkgs-unstable (pinArgs prev);
        stable = import inputs.nixpkgs-stable (pinArgs prev);
      })
    ];
    nixpkgs.config.allowUnfree = true;

    # Flakes, so `nixos-rebuild switch` works from the console and a direnv
    # `use flake` resolves inside a guest.
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Primary user.
    # The wheel group is the way in, since root is locked.
    # No password is set here, since that is host-only.
    # A guest therefore has none and is reached by SSH key or `machinectl`.
    users.users.${user.name} = {
      isNormalUser = true;
      description = user.description;
      extraGroups = [ "wheel" ];
    };

    # home-manager as a NixOS module: one build produces the system and user
    # environment together, sharing the system's pkgs and installing user
    # packages into the system profile.
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
