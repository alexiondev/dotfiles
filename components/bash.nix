{ pkgs, config, lib, ...}: {
  programs.bash = {
    enable = true;

    shellAliases = {
      ".."  = "cd ..";
      "..." = "cd ../..";

      ls    = "ls --color=auto";
      ll    = "ls --color=auto -l";

      vim   = "nvim";
    };

    sessionVariables = {
        EDITOR = "nvim";
    };    
  };
}