{
  config,
  lib,
  ...
}:
# SSH on this machine, in both directions.
let
  cfg = config.modules.ssh;
  user = config.user.name;

  hostKeySecret = type: "ssh-host-${type}-key";
  userKeySecret = "ssh-user-ed25519-key";

in
{
  options.modules.ssh = {
    enable = lib.mkEnableOption "the OpenSSH daemon, with host keys restored from secrets";

    workstationKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxQ4kWsBo2OGYIPOkFe0vNEcB3yoJwAu0y9wrdQzALE alexion@neogaia"
      ];
      description = ''
        Client public keys of the machines the operator works from.

        Every machine admits these, so any of them reaches the whole fleet.
      '';
    };

    serverKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Client public keys of the machines that serve.

        Only other servers admit these, so one that is compromised reaches no
        machine the operator works from.
      '';
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = cfg.workstationKeys;
      defaultText = lib.literalExpression "config.modules.ssh.workstationKeys";
      description = ''
        Client public keys this machine admits for the primary user, drawn from
        the lists above.

        A machine the operator works from takes the workstation keys. One that
        serves takes both, so servers reach each other. The default admits the
        workstation keys, since a machine admitting none is unreachable.
      '';
    };

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
    users.users.${user}.openssh.authorizedKeys.keys = cfg.authorizedKeys;

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
