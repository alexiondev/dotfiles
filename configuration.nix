  # Configure keymap in X11
  services.xserver.layout = "us";
  services.xserver.xkbOptions = "caps:swapescape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      tappingDragLock = true;
      scrollMethod = "twofinger";
      naturalScrolling = false;
      horizontalScrolling = true;
      disableWhileTyping = true;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.alexion = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video"]; # Enable ‘sudo’ for the user.
  };
  
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim
    git
    wget
    firefox
  ];
  
  programs.light.enable = true;


  # nix.package = pkgs.nixUnstable;
  # nix.extraOptions = ''
  #   experimental-features = nix-command flakes
  # '';
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}

