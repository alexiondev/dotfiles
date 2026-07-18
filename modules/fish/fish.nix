{
  config,
  lib,
  pkgs,
  ...
}:
# fish for the primary user, configured natively through home-manager. Wires the
# done and bang-bang plugins, a fastfetch greeting, a bat-backed manpager, helper
# functions, the eza aliases, and vi-style command-line editing. Set fish as the
# default login shell by also turning on `modules.fish.defaultShell`.
let
  cfg = config.modules.fish;
  user = config.user.name;
in
{
  options.modules.fish = {
    enable = lib.mkEnableOption "fish as the user's shell, configured via home-manager";

    defaultShell = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Set fish as the user's default login shell.";
    };
  };

  config = lib.mkIf cfg.enable {
    # System-level fish: registers it in /etc/shells and installs vendor
    # completions.
    programs.fish.enable = true;
    users.users.${user}.shell = lib.mkIf cfg.defaultShell pkgs.fish;

    home-manager.users.${user} = {
      home.packages = with pkgs; [
        eza # modern ls with git awareness and icons; backs the ls aliases
        bat # syntax-highlighting cat/pager; backs the manpager below
        fastfetch # system-info banner printed as the shell greeting
        wget # non-interactive HTTP downloader; backs the wget abbreviation
      ];

      # done's tuning lives in its own conf.d snippet, mirroring ~/.config/fish.
      xdg.configFile."fish/conf.d/done.fish".source = ./conf.d/done.fish;

      programs.fish = {
        enable = true;

        # Relied-on upstream defaults, pinned so a future change can't silently
        # alter behaviour.
        generateCompletions = true;

        # Prefer abbreviations over aliases when other modules wire up fish
        # shortcuts, matching the abbreviation-first style below.
        preferAbbrs = true;

        # done notifies when a long command finishes; bang-bang restores the !!
        # and !$ history bindings.
        plugins = [
          {
            name = "done";
            src = pkgs.fishPlugins.done.src;
          }
          {
            name = "bang-bang";
            src = pkgs.fishPlugins.bang-bang.src;
          }
        ];

        # Only the eza listings stay aliases; everything else is an abbreviation.
        shellAliases = {
          ls = "eza -al --color=always --group-directories-first --icons";
          la = "eza -a --color=always --group-directories-first --icons";
          ll = "eza -l --color=always --group-directories-first --icons";
          lt = "eza -aT --color=always --group-directories-first --icons";
          "l." = "eza -a | grep -e '^\\.'";
        };

        shellAbbrs = {
          # Walk up the tree.
          ".." = "cd ..";
          "..." = "cd ../..";
          "...." = "cd ../../..";

          vi = "nvim";
          vim = "nvim";
          cp = "cp -v";
          tmx = "tmux new-session -A -s";

          tarnow = "tar -acf ";
          untar = "tar -zxvf ";
          wget = "wget -c ";
          grep = "grep --color=auto";
          fgrep = "fgrep --color=auto";
          egrep = "egrep --color=auto";
          jctl = "journalctl -p 3 -xb";

          # Rebuild the system, and reclaim disk from old generations.
          update = "sudo nixos-rebuild switch";
          cleanup = "sudo nix-collect-garbage -d";
        };

        functions = {
          # Run fastfetch as the welcome message.
          fish_greeting = "fastfetch";

          history = {
            description = "Show command history with timestamps";
            body = "builtin history --show-time='%F %T '";
          };

          backup = {
            description = "Copy <file> to <file>.bak";
            argumentNames = "filename";
            body = "cp $filename $filename.bak";
          };

          copy = {
            description = "Copy a file, or recursively copy a source directory into a destination";
            body = builtins.readFile ./functions/copy.fish;
          };
        };

        interactiveShellInit = builtins.readFile ./config.fish;
      };
    };
  };
}
