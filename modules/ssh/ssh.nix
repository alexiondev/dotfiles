{
  config,
  lib,
  ...
}:
# The OpenSSH daemon, serving host keys restored from secrets.
let
  cfg = config.modules.ssh;

  secretName = type: "ssh-host-${type}-key";
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
  };

  config = lib.mkIf cfg.enable {
    services.openssh.enable = true;

    # The daemon reads its host keys once at startup, so a re-key has to restart
    # it to take effect.
    sops.secrets = lib.genAttrs (map secretName cfg.hostKeys.types) (_: {
      inherit (cfg.hostKeys) sopsFile;
      mode = "0400";
      restartUnits = [ "sshd.service" ];
    });

    # An empty list is what stops the daemon generating keys of its own.
    services.openssh.hostKeys = [ ];
    services.openssh.extraConfig = lib.concatMapStrings (
      type: "HostKey ${config.sops.secrets.${secretName type}.path}\n"
    ) cfg.hostKeys.types;
  };
}
