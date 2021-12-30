{ ... }: {
  services.xserver = {
    layout = "us";
    xkbOptions = "caps:swapescape";
    libinput.enable = true;
  };
}
