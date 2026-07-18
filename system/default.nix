{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
# The Skeleton's shared base config: the pieces every Host carries regardless of
# which Modules it enables — overlays, the `user`, flakes, and home-manager.
let
  inherit (lib) mkOption types;
  user = config.user;

  # Instantiate an extra nixpkgs source for the same platform as the base pkgs.
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
        The primary interactive user this Host is built for. An explicit option
        with no impure environment lookup, so the config is reproducible and
        honest about who the user is. Drives both the system account and the
        home-manager user in lockstep.
      '';
    };
    description = mkOption {
      type = types.str;
      default = "Alexion";
      description = "Human-readable description (GECOS field) for the primary user.";
    };
  };

  config = {
    # Base is nixos-unstable; reach a package fresher with `unstable.<name>` or
    # pin it rock-solid with `stable.<name>`. chaotic's overlay is added by its
    # own NixOS module, imported by the host-builder.
    nixpkgs.overlays = [
      (_final: prev: {
        unstable = import inputs.nixpkgs-unstable (pinArgs prev);
        stable = import inputs.nixpkgs-stable (pinArgs prev);
      })
    ];
    nixpkgs.config.allowUnfree = true;

    # Flakes + a baseline so `nixos-rebuild switch` works from the console.
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    environment.systemPackages = [ pkgs.git ];

    # Primary user, in wheel. The bootstrap password is set by hand at install
    # time and never committed; moving it to a sops-backed hashedPasswordFile is
    # the first post-boot task (out of scope for the MVI).
    users.users.${user.name} = {
      isNormalUser = true;
      description = user.description;
      extraGroups = [ "wheel" ];
    };

    # home-manager as a NixOS module: one `nixos-rebuild switch` builds the
    # system and the user environment atomically, sharing the system's pkgs
    # (with our overlays) and installing user packages into the system profile.
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
