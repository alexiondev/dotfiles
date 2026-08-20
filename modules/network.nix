{
  config,
  lib,
  my,
  ...
}:
# The host networking foundation: per-VLAN bridges over a tagged trunk.
let
  cfg = config.modules.network;

  # Each tagged VLAN materializes as a bridge named for its id, by the shared
  # convention.
  inherit (my) bridgeName;

  # The tagged sub-interface stacked on the trunk that feeds one bridge.
  vlanName = id: "${cfg.trunk}.${toString id}";
in
{
  options.modules.network = {
    enable =
      lib.mkEnableOption "the host trunk, its tagged-VLAN bridges, and the host management address";

    trunk = lib.mkOption {
      type = lib.types.str;
      example = "enp1s0";
      description = ''
        The physical interface carrying 802.1Q-tagged traffic for every VLAN.
        Each declared VLAN is stacked on it and enslaved to its own bridge.
      '';
    };

    vlans = lib.mkOption {
      type = lib.types.listOf (lib.types.ints.between 1 4094);
      default = [ ];
      example = [
        10
        20
        30
      ];
      description = ''
        The tagged VLAN ids to materialize. Each id N emits exactly one bridge
        named `br-vlanN`, and guests on VLAN N attach to it.
      '';
    };

    endpoint = {
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "10.23.50.146";
        description = ''
          Expected IP address assigned outside NixOS for this host's network
          endpoint. Left null, this host contributes no host endpoint to the
          fleet endpoint registry.
        '';
      };
    };

    endpoints = lib.mkOption {
      type = lib.types.attrsOf my.networkEndpoints.endpointType;
      default = { };
      description = ''
        Network endpoint declarations contributed by placed workloads on this
        host, keyed by their local stable endpoint name.
      '';
    };

    management = {
      vlan = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 1 4094);
        default = null;
        description = ''
          The VLAN whose bridge carries the host's own management address; must
          be one of `vlans`. Left null, the host takes no address on any bridge
          and the bridges serve guests alone.
        '';
      };

      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "10.0.10.2/24";
        description = ''
          The host's static management address, in CIDR form, on the management
          VLAN's bridge. Left null, the host takes its address there by DHCP.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.management.vlan == null || lib.elem cfg.management.vlan cfg.vlans;
        message = "modules.network.management.vlan (${toString cfg.management.vlan}) must name one of modules.network.vlans.";
      }
      {
        assertion = cfg.management.address == null || cfg.management.vlan != null;
        message = "modules.network.management.address needs modules.network.management.vlan to say which bridge carries it.";
      }
    ];

    # networkd owns the trunk, its VLAN sub-interfaces, and the bridges, so a host
    # also running NetworkManager leaves them to networkd rather than contending.
    networking.networkmanager.unmanaged =
      [ "interface-name:${cfg.trunk}" ]
      ++ map (id: "interface-name:${bridgeName id}") cfg.vlans
      ++ map (id: "interface-name:${vlanName id}") cfg.vlans;

    systemd.network = {
      enable = true;

      netdevs = lib.mkMerge (
        map (id: {
          "40-${bridgeName id}" = {
            netdevConfig = {
              Name = bridgeName id;
              Kind = "bridge";
            };
          };
          "40-${vlanName id}" = {
            netdevConfig = {
              Name = vlanName id;
              Kind = "vlan";
            };
            vlanConfig.Id = id;
          };
        }) cfg.vlans
      );

      networks = lib.mkMerge (
        [
          # The trunk carries only tagged frames up to the sub-interfaces and
          # takes no address of its own.
          {
            "30-${cfg.trunk}" = {
              matchConfig.Name = cfg.trunk;
              networkConfig.LinkLocalAddressing = "no";
              linkConfig.RequiredForOnline = "no";
              vlan = map vlanName cfg.vlans;
            };
          }
        ]
        ++ map (id: {
          # Enslaved to its bridge, carrying no address itself.
          "40-${vlanName id}" = {
            matchConfig.Name = vlanName id;
            networkConfig.Bridge = bridgeName id;
            linkConfig.RequiredForOnline = "no";
          };
          # The management VLAN's bridge carries the host address; every other
          # bridge is a plain L2 segment for guests.
          "40-${bridgeName id}" = lib.mkMerge [
            {
              matchConfig.Name = bridgeName id;
              linkConfig.RequiredForOnline = "no";
            }
            (lib.mkIf (cfg.management.vlan == id) (
              if cfg.management.address == null then
                { networkConfig.DHCP = "yes"; }
              else
                { address = [ cfg.management.address ]; }
            ))
          ];
        }) cfg.vlans
      );
    };
  };
}
