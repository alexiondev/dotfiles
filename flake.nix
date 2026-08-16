{
  description = "Alexion's NixOS configuration — one flake for every host";

  inputs = {
    # Base channel.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Fresher packages, reachable per-package as `unstable.<name>`.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Latest stable release, reachable per-package as `stable.<name>`.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Signed AMO extensions, pinned by version and hash.
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Follows our nixpkgs so its plugins build against the same package set.
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning.
    # Each host declares its own layout.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Upstream per-machine hardware profiles.
    # Each host imports its own.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Decrypts committed secrets at activation, from an age identity on the host.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Themes the graphical layer from one base16 scheme.
    # Follows our nixpkgs so it themes the same package set the host builds.
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Agent-ergonomic CLI for Gitea, with a home-manager module for the agent context.
    gitea-axi = {
      url = "git+https://git.alexion.dev/alexion/gitea-axi";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Personal agent skills, packaged as per-skill derivations with a home-manager module.
    skills = {
      url = "git+https://git.alexion.dev/alexion/skills";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # CachyOS kernel and binary cache.
    # Pins its own nixpkgs so its cache stays usable and the kernel is fetched from it.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      my = import ./lib { inherit lib inputs self; };
    in
    {
      # Helper functions for discovering and building hosts.
      lib = my;

      # Every host under hosts/ is discovered and built.
      nixosConfigurations = my.mkHosts (self + "/hosts");

      # A project shell for agent-local resources that should travel with this
      # checkout rather than the operator's global profile.
      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.mkShell {
          packages = [ inputs.gitea-axi.packages.x86_64-linux.gitea-axi ];
          shellHook = inputs.skills.lib.mkSkillsShellHook [
            inputs.gitea-axi.packages.x86_64-linux.gitea-axi-skill
          ];
        };

      # `nix flake check` builds host toplevels and project-level checks.
      checks.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          serviceIdentities = import ./lib/service-identities.nix { inherit lib; };
          serviceIdentityTestsPass = lib.all (result: result) (lib.attrValues serviceIdentities.tests);
        in
        (lib.mapAttrs (
          name: host:
          if host.config.warnings == [] then
            host.config.system.build.toplevel
          else
            throw "Host ${name} has evaluation warnings:\n${lib.concatStringsSep "\n" host.config.warnings}"
        ) self.nixosConfigurations)
        // {
          service-identities = pkgs.runCommand "service-identities-check" { } ''
            ${lib.optionalString (!serviceIdentityTestsPass) "exit 1"}
            touch $out
          '';
        };
    };
}
