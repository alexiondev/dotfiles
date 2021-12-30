{ ... }: {
  home-manager.users.alexion.xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;

      desktop     = "$HOME/.desktop";
      documents   = "$HOME/doc";
      download    = "$HOME/dwn";
      music       = "$HOME/.hideme";
      pictures    = "$HOME/pic";
      publicShare = "$HOME/.hideme";
      templates   = "$HOME/.hideme";
      videos      = "$HOME/.hideme";
    };
  };
}