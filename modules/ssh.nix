{
  config,
  lib,
  ...
}:
# SSH on this machine, in both directions.
let
  cfg = config.modules.ssh;
  user = config.user.name;

  inherit (lib)
    concatLists
    concatStringsSep
    elem
    filter
    genAttrs
    hasAttr
    imap0
    listToAttrs
    mapAttrs
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    nameValuePair
    optional
    optionalAttrs
    types
    unique
    ;

  hostKeySecret = type: "ssh-host-${type}-key";
  userKeySecret = "ssh-user-ed25519-key";

  targetType = types.submodule (
    { name, ... }:
    {
      options = {
        hostName = mkOption {
          type = types.str;
          default = name;
          description = ''
            The network address OpenSSH connects to for this target.
          '';
        };

        user = mkOption {
          type = types.str;
          default = config.user.name;
          description = ''
            The remote login name OpenSSH uses for this target.
          '';
        };

        port = mkOption {
          type = types.port;
          default = 22;
          description = ''
            The TCP port OpenSSH uses for this target.
          '';
        };

        aliases = mkOption {
          type = types.listOf types.str;
          default = [ name ];
          description = ''
            Host patterns written into the generated OpenSSH client block.
          '';
        };

        clientKey = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            The public key this target offers when it connects outward.
            Other machines admit this key according to the host groups below.
          '';
        };

        hostKeys = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            The public keys this target presents when it accepts inbound SSH.
            These keys generate system-wide known-host entries.
          '';
        };
      };
    }
  );

  keyWithoutComment = key: concatStringsSep " " (lib.take 2 (lib.splitString " " key));

  targetNamesIn = names: filter (name: hasAttr name cfg.targets) names;

  workstationNames = targetNamesIn cfg.hosts.workstations;
  serverNames = targetNamesIn cfg.hosts.servers;

  clientKeysFor = names: filter (key: key != null) (map (name: cfg.targets.${name}.clientKey) names);

  currentHost = config.networking.hostName;
  isServer = elem currentHost cfg.hosts.servers;
  isWorkstation = elem currentHost cfg.hosts.workstations;

  defaultAuthorizedKeys = lib.flatten (
    clientKeysFor workstationNames
    ++ optional isServer (clientKeysFor serverNames)
  );

  outboundTargetNames =
    let
      groupTargets =
        if isServer then
          [ "gitea" ] ++ cfg.hosts.servers
        else if isWorkstation then
          [ "gitea" ] ++ cfg.hosts.servers ++ cfg.hosts.workstations
        else
          [ "gitea" ];
    in
    filter (name: name != currentHost) (targetNamesIn groupTargets);

  sshSettingsFor = name:
    let
      target = cfg.targets.${name};
    in
    {
      header = "Host ${concatStringsSep " " target.aliases}";
      HostName = target.hostName;
      User = target.user;
    }
    // optionalAttrs (target.port != 22) { Port = target.port; };

  knownHostNamesFor = target:
    let
      names = unique (target.aliases ++ [ target.hostName ]);
      withPort = name: if target.port == 22 then name else "[${name}]:${toString target.port}";
    in
    map withPort names;

  knownHosts = listToAttrs (
    concatLists (
      mapAttrsToList (
        targetName: target:
        imap0 (i: key:
          nameValuePair "${targetName}-${toString i}" {
            hostNames = knownHostNamesFor target;
            publicKey = keyWithoutComment key;
          }
        ) target.hostKeys
      ) cfg.targets
    )
  );
in
{
  options.modules.ssh = {
    enable = lib.mkEnableOption "the OpenSSH daemon, with host keys restored from secrets";

    hosts = {
      servers = mkOption {
        type = types.listOf types.str;
        default = [ "pikachu" ];
        description = ''
          Hosts that serve durable services.
          They admit workstation keys and server keys, and they receive aliases for other servers and the forge.
        '';
      };

      workstations = mkOption {
        type = types.listOf types.str;
        default = [ "neogaia" ];
        description = ''
          Hosts the operator works from.
          Their keys are admitted by every host, and they receive aliases for the whole fleet and the forge.
        '';
      };
    };

    targets = mkOption {
      type = types.attrsOf targetType;
      default = {
        gitea = {
          hostName = "git.alexion.dev";
          port = 2022;
          user = "gitea";
          aliases = [
            "gitea"
            "git.alexion.dev"
          ];
        };

        neogaia = {
          hostName = "10.23.50.146";
          clientKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxQ4kWsBo2OGYIPOkFe0vNEcB3yoJwAu0y9wrdQzALE alexion@neogaia";
          hostKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJS+wp7K123+4BT6G4f954R6WyrbWveY7VlpoBUf6I5p neogaia"
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCo2wWUKxyAS4J5TqbWf8glDhJvS5XmdRqFhMeJwG3pOB+4AccZ1T8LU7ZN+RjtRi3j2qXBJvIHuzhtQNtmT59TxocvfobYiqOgJpvVO5K6yD8ZoUJs6ziDkIduI9w9mdRIESoi+dBbVu8n24r61cKDVh+jWX+yjzkOcWcOzqDyQhhkjqblZ1WMAdujEMuEPvif1i2LCxStUaZqRGcx09m/ME2fYcaJrpuxxxvX2+CPJNicoo6Rx9i7ZjAoNuvH+jui4KT62DzlQtQtCl2CFUOM0gCPSa+MbNQ9elfHPvGzEcwOIMo2cuy9KURUkQu+sAgaG8S1PEniDDTecskHtuRdmPZawnQGpIhzo919Q6wUgjT8scK4mmSXRWmGmkMt0GNA2tfj5tDks6r5Q8XsYqtWs4rsOEvfmxVSdM771w+fqDBAil99Jsh0ksPK9+Bwgg8cMDzLLFDn8JA5y2G1HocMMom+u5DYKwPXEKnCILkasB8y24+O3PhSu1EuWw277w6EUEXvU03rCf0Ak/ULjxp9a00EGlloEwSmFI7Aub9XHDr87IdbGInEn+PMqyBYADiN+3h6nE2JO+nMa6i/CHdebmT+T7YJvuTKHD9sjFmQsYaghlq03DZrhHcm4hgUvE1dqGojHrhk/WgA3EWTWtK/+BP0Vy2jXaaz+qAx+EGnhQ== neogaia"
          ];
        };

        pikachu = {
          hostName = "10.23.10.102";
          clientKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINNqJIC6VRXyvrNf3n9su9KdPCikC3CjK/QrCK2reHdB alexion@pikachu";
          hostKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKljRf4pJO+pqEqjpPz08gOYq3g1PpxvE66xVw7uMEnA root@pikachu"
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCy/riwm7dflA3mT+3a0/2CIoS2LbAsK/vn35kOoNeuzn0yhiF+imexP6tkB3S2t+H5ybRzkbbuNZcynFfeCqthFc8kvbdCnt8Diqoeg96fZ6ecvh5QE5yH9op8534EySetZ/exakFLnF+6EiWMuWUW3DFwsc2kcgDJObqSE8gTx/d7JK953MiTFmSJBFyg1RtQ3ZnMT+iCrvY2dyCLQai7VeF8koVKF2c0leAq2Hc75rb/L9md8MoJa64iPiz7hwTCin3xoFyaY/5hNVvyqFd5PivgR69gLdJkuVsUYO2mJzhur8cYmJD+pGjJ0U45hyE9TMrCFjeJHHuvSt3+2kph62wv95jLNk0WmMlwgyunISxENCSVVtNYdBMXhUh8VhEAW17QpVUg9EnPvxOdTKEjrvfOZYASWUa51JKbgBgexVgFbxdjDZR88DZa31AVBts/cx/59gXTUahFXMYLdZgssx+5uibZQWnvCyfUV9WLbfmK1lgL6hzReg1VkQ87iGr6skjtQYemJxRaFNA1+Q5f3kmG3KncuK/594a3qXYP4gC6A2blf8om1YZ4aXXh6f+GFKLjoEw1vvM2rJ+rjzfymwDX+pxVQ9L13OEtVZc9Ez76pOkbm1hqdbL0gY45+0cpxodhWV0wMQJBDXL1MHP8qcs+/vw0GxVK5l1SnWBGlw== root@pikachu"
          ];
        };
      };
      description = ''
        SSH targets known to the fleet.
        The inventory holds connection details plus public keys used for authorization and host verification.
      '';
    };

    extraAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Additional client public keys admitted by this host.
      '';
    };

    authorizedKeys = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      description = ''
        Complete override for client public keys admitted by this host.
        Leave null to derive access from `modules.ssh.hosts` and `modules.ssh.targets`.
      '';
    };

    extraSettings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        Additional OpenSSH client settings merged into the generated Home Manager configuration.
      '';
    };

    hostKeys.restore = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Restore the host keys from secrets rather than letting the daemon generate its own.
        A machine with its own identity keeps its fingerprint across a reimage by restoring committed keys.
        A guest carries no host identity, so it turns this off and presents a self-generated key instead.
      '';
    };

    hostKeys.sopsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Encrypted file holding this host's SSH host private keys, one entry per key type, named `ssh-host-<type>-key`.
        Required when `restore` is on.
      '';
    };

    hostKeys.types = mkOption {
      type = types.listOf types.str;
      default = [
        "ed25519"
        "rsa"
      ];
      description = ''
        Key types to restore, naming both the entries read from the encrypted file and the algorithms the daemon offers.
      '';
    };

    userKey.sopsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Encrypted file holding this machine's SSH client private key, under the entry `ssh-user-ed25519-key`.
        Left unset on a machine that authenticates to no remote server, such as a guest.
      '';
    };
  };

  config = mkIf cfg.enable (
    mkMerge [
      {
        services.openssh.enable = true;

        users.users.${user}.openssh.authorizedKeys.keys =
          if cfg.authorizedKeys != null then
            cfg.authorizedKeys
          else
            defaultAuthorizedKeys ++ cfg.extraAuthorizedKeys;

        programs.ssh.knownHosts = knownHosts;

        home-manager.users.${user}.programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings =
            mapAttrs (name: _: sshSettingsFor name) (genAttrs outboundTargetNames (name: name))
            // cfg.extraSettings;
        };
      }

      (mkIf cfg.hostKeys.restore {
        assertions = [
          {
            assertion = cfg.hostKeys.sopsFile != null;
            message = "modules.ssh.hostKeys.restore requires modules.ssh.hostKeys.sopsFile to name the encrypted host keys.";
          }
        ];

        sops.secrets = genAttrs (map hostKeySecret cfg.hostKeys.types) (_: {
          inherit (cfg.hostKeys) sopsFile;
          mode = "0400";
          restartUnits = [ "sshd.service" ];
        });

        services.openssh.hostKeys = [ ];
        services.openssh.extraConfig = concatStringsSep "" (
          map (type: "HostKey ${config.sops.secrets.${hostKeySecret type}.path}\n") cfg.hostKeys.types
        );
      })

      (mkIf (cfg.userKey.sopsFile != null) {
        sops.secrets.${userKeySecret} = {
          inherit (cfg.userKey) sopsFile;
          mode = "0400";
          owner = user;
        };

        home-manager.users.${user}.programs.ssh.settings."*".IdentityFile =
          config.sops.secrets.${userKeySecret}.path;
      })
    ]
  );
}
