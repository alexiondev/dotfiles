{
  config,
  lib,
  ...
}:
# SSH on this machine, in both directions.
let
  cfg = config.modules.ssh;
  user = config.user.name;

  fleet = import ../fleet;

  hostKeySecret = type: "ssh-host-${type}-key";
  userKeySecret = "ssh-user-ed25519-key";

  # The roles whose keys a machine of the given role authorizes.
  # A workstation admits workstations alone, so a server that is compromised
  # reaches no machine of the operator's own.
  authorizedRoles = {
    workstation = [ "workstation" ];
    server = [
      "workstation"
      "server"
    ];
  };

  machine = fleet.${config.networking.hostName} or null;

  # Guarded so that an unregistered machine fails the assertion below with a
  # readable message, rather than on a missing attribute here.
  registered = machine != null && authorizedRoles ? ${machine.role};

  authorizedKeys = lib.optionals registered (
    lib.mapAttrsToList (_name: m: m.sshPublicKey) (
      lib.filterAttrs (_name: m: lib.elem m.role authorizedRoles.${machine.role}) fleet
    )
  );

  undefinedRoles = lib.attrNames (lib.filterAttrs (_name: m: !(authorizedRoles ? ${m.role})) fleet);
in
{
  options.modules.ssh = {
    enable = lib.mkEnableOption "the OpenSSH daemon, with host keys restored from secrets";

    hostKeys.sopsFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Encrypted file holding this host's SSH host private keys, one entry per
        key type, named `ssh-host-<type>-key`.

        These are the keys the daemon presents to identify itself to connecting
        clients, not keys used to authenticate anyone to a remote server.
        Restoring them from secrets rather than generating them keeps the host's
        fingerprint across a reimage, so every client's `known_hosts` entry
        stays valid.
      '';
    };

    hostKeys.types = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "ed25519"
        "rsa"
      ];
      description = ''
        Key types to restore, naming both the entries read from the encrypted
        file and the algorithms the daemon offers. Dropping a type a client has
        already pinned makes the host unrecognisable to it.
      '';
    };

    userKey.sopsFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Encrypted file holding this machine's SSH client private key, under the
        entry `ssh-user-ed25519-key`.

        This is the key the primary user offers to authenticate to a remote
        server, not a key the daemon presents to identify this machine.
        It belongs to this machine alone, so withdrawing its access does not
        re-key any other.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = registered;
        message = ''
          modules.ssh: ${config.networking.hostName} is not in the fleet under a
          defined role, so the keys it authorizes cannot be derived.
        '';
      }
      {
        # An undefined role matches no policy, which would drop that machine's
        # access everywhere without failing anything.
        assertion = undefinedRoles == [ ];
        message = ''
          modules.ssh: fleet entries carry a role no policy defines: ${lib.concatStringsSep ", " undefinedRoles}.
        '';
      }
    ];

    services.openssh.enable = true;

    sops.secrets =
      # The daemon reads its host keys once at startup, so a re-key has to
      # restart it to take effect.
      lib.genAttrs (map hostKeySecret cfg.hostKeys.types) (_: {
        inherit (cfg.hostKeys) sopsFile;
        mode = "0400";
        restartUnits = [ "sshd.service" ];
      })
      // {
        # The primary user is the only account that authenticates with this key,
        # and the mode admits no other.
        # The client rereads it per connection, so no unit restarts on a re-key.
        ${userKeySecret} = {
          inherit (cfg.userKey) sopsFile;
          mode = "0400";
          owner = user;
        };
      };

    # An empty list is what stops the daemon generating keys of its own.
    services.openssh.hostKeys = [ ];
    services.openssh.extraConfig = lib.concatMapStrings (
      type: "HostKey ${config.sops.secrets.${hostKeySecret type}.path}\n"
    ) cfg.hostKeys.types;

    # The primary user is the only account reachable over SSH.
    users.users.${user}.openssh.authorizedKeys.keys = authorizedKeys;

    # The client reads the decrypted key where it is written, so no copy of it
    # lives in the user's home to drift from the secret.
    # Declaring no defaults of home-manager's own leaves every other directive
    # at the one OpenSSH itself ships.
    home-manager.users.${user}.programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*".IdentityFile = config.sops.secrets.${userKeySecret}.path;
    };
  };
}
