{ ... }: {
  services.xserver.libinput.touchpad = {
      tapping = true;
      tappingDragLock = true;
      scrollMethod = "twofinger";
      naturalScrolling = false;
      horizontalScrolling = true;
      disableWhileTyping = true;
  };
}