{
  lib,
  inputs,
  self,
}:
let
  inherit (lib)
    attrNames
    filterAttrs
    genAttrs
    flatten
    hasSuffix
    mapAttrsToList
    ;

  serviceIdentityRegistry = import ./service-identities.nix { inherit lib; };

  # Recursively collect every `.nix` file under `dir` as a flat list, for a
  # module's `imports`.
  collectNixFiles =
    dir:
    flatten (
      mapAttrsToList (
        name: type:
        let
          path = dir + "/${name}";
        in
        if type == "directory" then
          collectNixFiles path
        else if type == "regular" && hasSuffix ".nix" name then
          [ path ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  # The special arguments every configuration is evaluated with, host and guest
  # interior alike.
  specialArgs = {
    inherit inputs;
    my = self.lib;
  };

  # The name of a tagged VLAN's bridge, kept here as the one definition of a
  # convention shared across the flake.
  bridgeName = id: "br-vlan${toString id}";

  # A guest with no operator-set MAC derives a stable one from its namespace path.
  # The first octet 02 marks the address locally-administered and unicast.
  # The rest is a slice of the path's hash.
  # The same guest therefore always lands on the same address, which the operator can reserve at the router.
  deriveMac =
    name:
    let
      hash = builtins.hashString "sha256" name;
      octet = i: builtins.substring (i * 2) 2 hash;
    in
    lib.concatStringsSep ":" ([ "02" ] ++ map octet [ 0 1 2 3 4 ]);

  # Build one host: every module and every guest is imported unconditionally
  # (inert until its `enable` flag is set), alongside chaotic, the host base,
  # and the host's own directory.
  mkHost =
    {
      hostName,
      system ? "x86_64-linux",
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system specialArgs;
      modules =
        (collectNixFiles (self + "/modules"))
        ++ (collectNixFiles (self + "/guests"))
        ++ [
          inputs.chaotic.nixosModules.default
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
          inputs.stylix.nixosModules.stylix
          (self + "/system.nix")
          (self + "/hosts/${hostName}")
          { networking.hostName = hostName; }
        ];
    };

  # Build a guest: a module-shaped definition whose body realizes its interior
  # as a nested container standing on the guest-base, keyed by its namespace path.
  # `name` is the dotted namespace under `guests.` and `interior` is an extra
  # module merged into the container alongside the guest-base.
  guest =
    {
      name,
      interior ? { },
    }:
    { config, lib, ... }:
    let
      optionPath = [ "guests" ] ++ lib.splitString "." name;
      cfg = lib.getAttrFromPath optionPath config;
      machineName = lib.replaceStrings [ "." ] [ "-" ] name;

      networked = cfg.vlan != null;

      # Host paths the operator maps into the guest, keyed by their in-guest path.
      userMounts = lib.mapAttrs (_guestPath: m: {
        inherit (m) hostPath;
        isReadOnly = m.readOnly;
      }) cfg.mounts;

      # Each named secret bind-mounted read-only at the same `/run/secrets/<name>`
      # path it holds on the host.
      # No ownership is set here, since the container's one-to-one identity map
      # carries the host file's owner through unchanged.
      secretMounts = lib.listToAttrs (
        map (
          name:
          let
            path = config.sops.secrets.${name}.path;
          in
          lib.nameValuePair path {
            hostPath = path;
            isReadOnly = true;
          }
        ) cfg.secrets
      );

      # An in-guest path claimed by both a mount and a secret, which the merge
      # below would otherwise resolve silently in the secret's favour.
      mountCollisions = lib.attrNames (builtins.intersectAttrs userMounts secretMounts);

      # The resource caps the operator places on the guest's unit, dropping any
      # left unset so systemd keeps its uncapped default for those.
      limitConfig = lib.filterAttrs (_: v: v != null) {
        MemoryMax = cfg.limits.memory;
        CPUQuota = cfg.limits.cpu;
        TasksMax = cfg.limits.tasksMax;
      };

      # A networked guest owns its bridged interface through its own networkd, the only stable MAC pin for a nested container.
      # The interface is eth0, the name a nested container gives its bridged veth.
      # It takes the placement MAC, and the static address or DHCP when that is unset.
      guestNet =
        { lib, ... }:
        {
          config = lib.mkIf networked {
            networking.useNetworkd = true;

            # networkd default-enables resolved, which owns the guest's resolv.conf.
            # The nested-container default of inheriting the host's file conflicts with that, so the guest keeps its own.
            networking.useHostResolvConf = false;

            systemd.network.networks."20-eth0" = {
              matchConfig.Name = "eth0";
              linkConfig.MACAddress = cfg.mac;
              networkConfig = lib.mkIf (cfg.address == null) { DHCP = "yes"; };
              address = lib.mkIf (cfg.address != null) [ cfg.address ];
            };
          };
        };
    in
    {
      options = lib.setAttrByPath optionPath {
        enable = lib.mkEnableOption "the ${name} guest, run in its own nested container";
        backend = lib.mkOption {
          type = lib.types.enum [
            "container"
            "microvm"
          ];
          default = "container";
          description = ''
            How the guest is realized. `container` runs the guest as a
            systemd-nspawn nested container. `microvm` is reserved for a future
            hard-isolation backend and is not built yet.
          '';
        };
        vlan = lib.mkOption {
          type = lib.types.nullOr (lib.types.ints.between 1 4094);
          default = null;
          example = 10;
          description = ''
            The tagged VLAN this guest lives on. The guest attaches to its host's
            `br-vlan<id>` bridge for that VLAN. Left null, the guest keeps a
            private network with no bridge attachment. The id must be one of the
            host's `modules.network.vlans`.
          '';
        };
        mac = lib.mkOption {
          type = lib.types.str;
          default = deriveMac name;
          defaultText = lib.literalMD "a stable address derived from the guest's namespace path";
          example = "bc:24:11:00:00:01";
          description = ''
            The guest's MAC address on its VLAN, pinned inside the guest by its
            own networkd. Set it to reuse an existing address so a router's DHCP
            reservation keeps working. Left unset, a stable address is derived
            from the guest's namespace path in the locally-administered range.
          '';
        };
        address = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "10.0.10.5/24";
          description = ''
            The guest's static address, in CIDR form, on its VLAN. Left null, the
            guest takes its address by DHCP, keeping IP management at the router.
          '';
        };
        mounts = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                hostPath = lib.mkOption {
                  type = lib.types.str;
                  example = "/srv/media";
                  description = "The path on the host bind-mounted into the guest.";
                };
                readOnly = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Mount the path read-only. Read-write by default, since a
                    service must write to the pool data it owns.
                  '';
                };
              };
            }
          );
          default = { };
          example = lib.literalExpression ''
            {
              "/data/media" = { hostPath = "/srv/media"; };
              "/data/config" = {
                hostPath = "/srv/config/jellyfin";
                readOnly = true;
              };
            }
          '';
          description = ''
            Host paths bind-mounted into the guest, keyed by the path they appear
            at inside the guest, so a guest sees exactly the data it should at any
            granularity — a single folder or a whole pool. Each mount is
            read-write unless `readOnly` is set.
          '';
        };
        secrets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "jellyfin-api-key" ];
          description = ''
            Names of the secrets this guest needs. The host is the sole
            decryptor: it decrypts each named secret from its own sops files and
            bind-mounts the plaintext file into the guest read-only at
            `/run/secrets/<name>`, the same path it would occupy on a host, so a
            service reads its credentials at a predictable location. The guest
            names the files it wants and receives exactly those. It holds no age
            key and decrypts nothing itself. Ownership carries across unchanged,
            since the container maps ids one to one, so a secret owned by a uid on
            the host is owned by that same uid inside the guest.
          '';
        };
        limits = {
          memory = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "2G";
            description = ''
              Cap on the guest's memory, applied to its unit as `MemoryMax`.
              Accepts systemd size suffixes such as `512M` or `2G`. Left null,
              the guest's memory is uncapped.
            '';
          };
          cpu = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "150%";
            description = ''
              Cap on the guest's CPU, applied to its unit as `CPUQuota`, where
              `100%` is one full core. Left null, the guest's CPU is uncapped.
            '';
          };
          tasksMax = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            example = 512;
            description = ''
              Cap on the number of processes and threads the guest may spawn,
              applied to its unit as `TasksMax`. Left null, the task count is
              uncapped.
            '';
          };
        };
        nesting = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Grant the guest's interior the prerequisites to run Podman or other
            OCI containers of its own. Off by default, so a guest cannot nest
            containers. On, the guest's container gains the network-administration
            capability its container runtime uses to build bridges and firewall
            rules, along with the tun and fuse device nodes such a runtime reaches
            for, so the interior's `virtualisation.oci-containers` works with
            Podman as its default runtime.
          '';
        };
        autoStart = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Start the guest at boot. On by default. Disabled, the guest stays
            defined and can be started on demand, but does not come up at boot.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # Declared here so the host is the one that decrypts each named secret.
        # The guest carries no age key and decrypts nothing of its own.
        sops.secrets = lib.genAttrs cfg.secrets (_: { });

        assertions = [
          {
            assertion = mountCollisions == [ ];
            message = ''
              guests.${name} maps a mount at ${lib.concatStringsSep ", " mountCollisions}, colliding with a secret bind-mounted at the same path. Rename the mount or the secret so each in-guest path is used once.
            '';
          }
          {
            assertion = cfg.backend == "container";
            message = ''
              guests.${name}.backend = "${cfg.backend}" is not implemented. Only the "container" backend is built; "microvm" is reserved for future work.
            '';
          }
          {
            assertion = !networked || lib.elem cfg.vlan config.modules.network.vlans;
            message = ''
              guests.${name}.vlan = ${toString cfg.vlan} is not among its host's modules.network.vlans (${lib.concatMapStringsSep ", " toString config.modules.network.vlans}). Declare the VLAN on the host or correct the guest's placement.
            '';
          }
        ];

        # The operator's resource caps land on the guest's own unit, which a
        # networked guest also orders after the bridge its veth enslaves to at
        # start, since the container backend orders the unit after the network
        # is up but not after that specific bridge existing.
        systemd.services."container@${machineName}" = lib.mkIf (cfg.backend == "container") (
          lib.mkMerge [
            { serviceConfig = limitConfig; }
            (lib.mkIf networked (
              let
                bridgeDevice = "sys-subsystem-net-devices-${lib.replaceStrings [ "-" ] [ "\\x2d" ] (bridgeName cfg.vlan)}.device";
              in
              {
                after = [ bridgeDevice ];
                wants = [ bridgeDevice ];
              }
            ))
          ]
        );

        containers.${machineName} = lib.mkIf (cfg.backend == "container") {
          autoStart = cfg.autoStart;

          # The guest gets its own network namespace, so its services — its own
          # sshd included — never contend with the host's.
          privateNetwork = lib.mkDefault true;

          # A networked guest's veth is enslaved to the VLAN's bridge, making it
          # a first-class L2 citizen on that segment.
          hostBridge = lib.mkIf networked (bridgeName cfg.vlan);

          # The container shares the host's uid and gid space one to one.
          # A guest process writing as the shared storage group then lands on a bind-mounted pool as that same group, with no permission juggling.
          # A private-user mapping would shift the ids and reintroduce those errors, so it stays off.
          privateUsers = lib.mkDefault "no";

          # A nesting guest runs Podman or other OCI containers in its interior.
          # The network-administration capability lets that runtime build its
          # bridges and firewall rules.
          # The tun and fuse device nodes are what it reaches for to network
          # those containers and back their overlay storage.
          # The remaining prerequisite, a delegated cgroup subtree for the
          # runtime to manage, the container backend already grants every guest.
          additionalCapabilities = lib.optionals cfg.nesting [ "CAP_NET_ADMIN" ];
          allowedDevices = lib.optionals cfg.nesting [
            {
              node = "/dev/net/tun";
              modifier = "rwm";
            }
            {
              node = "/dev/fuse";
              modifier = "rwm";
            }
          ];

          bindMounts = userMounts // secretMounts;

          inherit specialArgs;

          config = {
            imports = [
              (self + "/guest.nix")
              guestNet
              interior
            ];
          };
        };
      };
    };

  # Discover every host (a subdirectory of `hostsDir`) and build each one.
  mkHosts =
    hostsDir:
    let
      hostNames = attrNames (filterAttrs (_name: type: type == "directory") (builtins.readDir hostsDir));
    in
    genAttrs hostNames (hostName: mkHost { inherit hostName; });
in
{
  inherit
    collectNixFiles
    mkHost
    mkHosts
    guest
    bridgeName
    ;
  inherit (serviceIdentityRegistry) serviceUid;
  serviceIdentities = serviceIdentityRegistry.identities;
}
