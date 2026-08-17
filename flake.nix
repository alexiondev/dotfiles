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

          reverse-proxy-basic-route =
            let
              testConfig =
                (lib.nixosSystem {
                  system = "x86_64-linux";
                  specialArgs.my = self.lib;
                  modules = [
                    ./modules/reverse-proxy.nix
                    {
                      modules.reverse-proxy = {
                        enable = true;
                        routes."budget.alexion.dev" = {
                          path = "/";
                          backend = "http://10.23.20.42:5006";
                        };
                      };
                    }
                  ];
                }).config;
              vhost = testConfig.services.nginx.virtualHosts."budget.alexion.dev";
            in
            pkgs.runCommand "reverse-proxy-basic-route-check" { } ''
              ${
                lib.optionalString (
                  !(vhost.forceSSL && vhost.enableACME && vhost.locations."/".proxyPass == "http://10.23.20.42:5006")
                ) "exit 1"
              }
              touch $out
            '';

          reverse-proxy-actualbudget-guest-route =
            let
              testConfig =
                (self.nixosConfigurations.pikachu.extendModules {
                  modules = [
                    {
                      guests.actualbudget.reverseProxy = {
                        enable = true;
                        host = "budget.alexion.dev";
                        backend = "http://10.23.20.42:5006";
                      };
                    }
                  ];
                }).config;
              route = testConfig.modules.reverse-proxy.routes.actualbudget;
            in
            pkgs.runCommand "reverse-proxy-actualbudget-guest-route-check" { } ''
              ${
                lib.optionalString (
                  !(route.host == "budget.alexion.dev" && route.backend == "http://10.23.20.42:5006")
                ) "exit 1"
              }
              touch $out
            '';

          reverse-proxy-secondary-path-requires-root =
            let
              testConfig =
                (lib.nixosSystem {
                  system = "x86_64-linux";
                  specialArgs.my = self.lib;
                  modules = [
                    ./modules/reverse-proxy.nix
                    {
                      modules.reverse-proxy = {
                        enable = true;
                        routes.raichu-files = {
                          host = "files.alexion.dev";
                          path = "/raichu";
                          backend = "http://10.23.20.10:3923";
                        };
                      };
                    }
                  ];
                }).config;
              hasFailedRootAssertion = lib.any (
                assertion:
                assertion.assertion == false
                && assertion.message == "modules.reverse-proxy.routes for files.alexion.dev must include a primary / route."
              ) testConfig.assertions;
            in
            pkgs.runCommand "reverse-proxy-secondary-path-requires-root-check" { } ''
              ${lib.optionalString (!hasFailedRootAssertion) "exit 1"}
              touch $out
            '';
        };
    };
}
