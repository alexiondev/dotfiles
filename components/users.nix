{ lib, ... }: {
  users.mutableUsers = false;
  users.users.alexion = {
      isNormalUser = true;
      extraGroups = [
          "wheel"
          "video"
      ];
      password = "";
  };
  
  home-manager.users.alexion.home = {
    username = "alexion";
    homeDirectory = "/home/alexion";
    stateVersion = "21.11";
  };
  
  environment.loginShellInit = lib.mkBefore ''
    [[ -z $DISPLAY && $(tty) == /dev/tty1 ]] && startx
  '';

  system.stateVersion = "21.11";
}