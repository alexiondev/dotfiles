{ pkgs, config, lib, ...}:

{
  programs.bash = {
    enable = true;

    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";

      ls = "ls --color=auto";
      ll = "ls -l --color=auto";
      vim = "nvim";
    };

    sessionVariables = {
      EDITOR = "nvim";
      PS1 = "
    };
    
    profileExtra = ''
      # Start X server on login to tty1
      if [[ -z ''${DISPLAY} && $(tty) == /dev/tty1 ]]; then
        startx
      fi
    '';
  };

}