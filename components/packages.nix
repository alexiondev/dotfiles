{ pkgs, ... }: {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  
  home-manager.users.alexion = {
    home.packages = with pkgs; [
      alacritty
      discord
      firefox
      git
      light
      neovim
      nix-index
      pavucontrol
      playerctl
      pulseaudio
      rofi
      spotify
      wget
      xclip
      xdotool

      font-awesome
      hack-font
    ];
    
    programs = {
      home-manager.enable = true;

      alacritty.enable = true;
      rofi.enable = true;
      vscode.enable = true;
    };
  };

  services = {
    picom.enable = true;
  };
}
