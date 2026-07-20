{
  config,
  lib,
  pkgs,
  ...
}:
# fish for the primary user, configured through home-manager.
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
    # System-level fish registers it in /etc/shells and installs vendor completions.
    programs.fish.enable = true;
    users.users.${user}.shell = lib.mkIf cfg.defaultShell pkgs.fish;

    home-manager.users.${user} = {
      home.packages = with pkgs; [
        eza # backs the ls/la/ll aliases
        bat # backs the manpager
        fastfetch # the shell greeting
        wget # backs the wget abbreviation
      ];

      programs.fish = {
        enable = true;

        preferAbbrs = true;

        plugins = [
          # Notify when a long command finishes.
          {
            name = "done";
            src = pkgs.fishPlugins.done.src;
          }
          # Restore the !! and !$ history bindings.
          {
            name = "bang-bang";
            src = pkgs.fishPlugins.bang-bang.src;
          }
        ];

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
          update = "sudo nixos-rebuild switch --flake .#${config.networking.hostName}";
          cleanup = "sudo nix-collect-garbage -d";
        };

        functions = {
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

        # Rendered by home-manager into ~/.config/fish/config.fish.
        interactiveShellInit = builtins.readFile ./config.fish;
      };
    };
  };
}
