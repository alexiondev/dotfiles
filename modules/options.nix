{ config, lib, options, pkgs, ... }:

with lib.my;
{
  options = with lib.types; {
    user = mkOpt attrs { };
  };

  config = {
    user =
      let
        user = builtins.getEnv "USER";
        name = if lib.elem user [ "" "root" ] then "alexion" else user;
      in
      {
        inherit name;
        extraGroups = [ "wheel" ];
        isNormalUser = true;
        home = "/home/${name}";
        group = "users";
        uid = 1000;
        initialPassword = "";
      };

    users.users.${config.user.name} = lib.mkAliasDefinitions options.user;
    users.users.root.initialPassword = "";

    home-manager = {
      backupFileExtension = "__old";
      useUserPackages = true;

      users.${config.user.name} = {
        nixpkgs.config.allowUnfree = true;

        home = {
          username = config.user.name;
          homeDirectory = config.user.home;

          stateVersion = config.system.stateVersion;
        };
      };
    };
  };
}
