{
  config,
  lib,
  ...
}:
# The host-level ZFS pool import: durable service state a host mounts, never rebuilds.
let
  cfg = config.modules.zfs;
in
{
  options.modules.zfs = {
    enable = lib.mkEnableOption "importing durable ZFS pools that hold service state";

    hostId = lib.mkOption {
      type = lib.types.strMatching "[0-9a-f]{8}";
      example = "deadbeef";
      description = ''
        This host's 8-hex-digit ZFS host id, written to `networking.hostId`. ZFS
        stamps an imported pool with the importing host's id, so a pool still
        held by another machine is refused rather than silently dual-mounted. It
        must be fixed for the machine and distinct across machines that can reach
        the same pool.
      '';
    };

    pools = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.path);
      default = { };
      example = lib.literalExpression ''
        {
          tank = {
            media = "/srv/media";
            downloads = "/srv/downloads";
          };
        }
      '';
      description = ''
        The ZFS pools to import at boot, keyed by pool name, each pool mapping a
        dataset path relative to it to that dataset's mountpoint. A pool is
        durable state imported as it stands, never created or destroyed by a
        rebuild, so a service's data survives any rebuild or reimage. A pool
        with an empty map is still imported, leaving each dataset to its own ZFS
        `mountpoint` property.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The ZFS stack in the kernel and boot, needed even where the root filesystem is another kind.
    boot.supportedFilesystems = [ "zfs" ];

    # ZFS refuses to import a pool without a host id to stamp its ownership onto.
    networking.hostId = cfg.hostId;

    # The declared pools are imported at boot, distinct from any pool backing the root filesystem.
    boot.zfs.extraPools = lib.attrNames cfg.pools;

    # Each declared dataset is mounted at its host path as a native ZFS filesystem.
    fileSystems = lib.mkMerge (
      lib.mapAttrsToList (
        pool: mounts:
        lib.mapAttrs' (
          dataset: mountpoint:
          lib.nameValuePair mountpoint {
            device = "${pool}/${dataset}";
            fsType = "zfs";
          }
        ) mounts
      ) cfg.pools
    );
  };
}
