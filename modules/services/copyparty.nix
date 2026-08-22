{
  config,
  lib,
  my,
  pkgs,
  ...
}:
let
  cfg = config.modules.services.copyparty;

  volumeType = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        description = "Filesystem path served by this volume.";
      };

      access = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = { };
        example = {
          A = [ "alexion" ];
        };
        description = "Copyparty access map from permission string to account names.";
      };

      flags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "dthumb" ];
        description = "Copyparty volume flags.";
      };
    };
  };

  renderAccess = permission: accounts: "    ${permission}: ${lib.concatStringsSep ", " accounts}";

  renderFlags = flags: lib.concatMapStringsSep "\n" (flag: "    ${flag}") flags;

  renderVolume = urlPath: volume: ''
    [${urlPath}]
      ${volume.path}
      accs:
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList renderAccess volume.access)}
    ${lib.optionalString (volume.flags != [ ]) ''
      flags:
    ${renderFlags volume.flags}
    ''}
  '';

  renderTrustedSource = source: "  xff-src: ${source}";

  renderedReverseProxy = lib.optionalString cfg.reverseProxy.enable ''
      rproxy: 1
      xff-hdr: x-forwarded-for
    ${lib.concatStringsSep "\n" (map renderTrustedSource cfg.reverseProxy.trustedSources)}
  '';

  renderedVolumes = lib.concatStringsSep "\n" (lib.mapAttrsToList renderVolume cfg.volumes);

  configScript = pkgs.writeShellScript "copyparty-config" ''
    set -eu

    umask 077
    password="$(${pkgs.coreutils}/bin/tr -d '\n' < "$CREDENTIALS_DIRECTORY/password")"

    cat > /run/copyparty/copyparty.conf <<EOF
    [global]
      p: ${toString cfg.port}
      usernames
      http-only
      no-crt
      no-thumb
      no-snap
      no-rescan
      ses-db: ${cfg.stateDir}/sessions.db
      chpw-db: ${cfg.stateDir}/chpw.json
      shr-db: ${cfg.stateDir}/shares.db
    ${renderedReverseProxy}
    [accounts]
      ${cfg.accountName}: $password

    ${renderedVolumes}
    EOF
  '';
in
{
  options.modules.services.copyparty = {
    enable = lib.mkEnableOption "Copyparty";

    package = lib.mkPackageOption pkgs "copyparty-min" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3923;
      description = "Port Copyparty listens on.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "copyparty";
      description = "User account that runs Copyparty.";
    };

    uid = lib.mkOption {
      type = lib.types.ints.positive;
      default = my.serviceUid "copyparty";
      description = "Stable uid for the Copyparty service user.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "storage";
      description = "Group account that owns Copyparty's writable state and served files.";
    };

    accountName = lib.mkOption {
      type = lib.types.str;
      default = "alexion";
      description = "Copyparty account name configured for password authentication.";
    };

    passwordFile = lib.mkOption {
      type = lib.types.path;
      description = "Runtime file containing the Copyparty account password.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/copyparty";
      description = "Directory where Copyparty stores service state.";
    };

    volumes = lib.mkOption {
      type = lib.types.attrsOf volumeType;
      default = { };
      description = "Copyparty volumes keyed by their URL path.";
    };

    reverseProxy = {
      enable = lib.mkEnableOption "reverse-proxy trust settings for Copyparty";

      trustedSources = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "IP ranges that may supply Copyparty's forwarded client IP header.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.volumes != { };
        message = "modules.services.copyparty.volumes must declare at least one served volume.";
      }
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.trustedSources != [ ];
        message = "modules.services.copyparty.reverseProxy.trustedSources must name at least one trusted proxy source when reverse-proxy support is enabled.";
      }
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      uid = cfg.uid;
      group = cfg.group;
      home = cfg.stateDir;
    };

    systemd.services.copyparty = {
      description = "Copyparty file server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ReloadSignal = "SIGUSR1";
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        Environment = [
          "HOME=${cfg.stateDir}"
          "XDG_CONFIG_HOME=${cfg.stateDir}"
        ];
        StateDirectory = "copyparty";
        RuntimeDirectory = "copyparty";
        RuntimeDirectoryMode = "0700";
        LoadCredential = [ "password:${cfg.passwordFile}" ];
        ExecStartPre = configScript;
        ExecStart = "${lib.getExe cfg.package} -c /run/copyparty/copyparty.conf";
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.stateDir ] ++ map (volume: volume.path) (lib.attrValues cfg.volumes);
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
