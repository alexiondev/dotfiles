{
  config,
  lib,
  pkgs,
  ...
}:
# fish for the primary user, configured natively through home-manager and set
# as their default login shell. Wires the done and bang-bang plugins, a
# fastfetch greeting, a bat-backed manpager, helper functions, and the eza and
# navigation aliases.
let
  cfg = config.modules.fish;
  user = config.user.name;
in
{
  options.modules.fish.enable = lib.mkEnableOption "fish as the user's shell, configured via home-manager";

  config = lib.mkIf cfg.enable {
    # System-level fish: registers it in /etc/shells and installs vendor
    # completions.
    programs.fish.enable = true;
    users.users.${user}.shell = pkgs.fish;

    home-manager.users.${user} = {
      home.packages = with pkgs; [
        eza
        bat
        fastfetch
        wget
      ];

      programs.fish = {
        enable = true;

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

        shellAliases = {
          # Replace ls with eza.
          ls = "eza -al --color=always --group-directories-first --icons";
          la = "eza -a --color=always --group-directories-first --icons";
          ll = "eza -l --color=always --group-directories-first --icons";
          lt = "eza -aT --color=always --group-directories-first --icons";
          "l." = "eza -a | grep -e '^\\.'";

          # Walk up the tree.
          ".." = "cd ..";
          "..." = "cd ../..";
          "...." = "cd ../../..";
          "....." = "cd ../../../..";
          "......" = "cd ../../../../..";

          vi = "nvim";
          vim = "nvim";
          cp = "cp -v";
          tmx = "tmux new-session -A -s";

          tarnow = "tar -acf ";
          untar = "tar -zxvf ";
          wget = "wget -c ";
          psmem = "ps auxf | sort -nr -k 4";
          psmem10 = "ps auxf | sort -nr -k 4 | head -10";
          dir = "dir --color=auto";
          vdir = "vdir --color=auto";
          grep = "grep --color=auto";
          fgrep = "fgrep --color=auto";
          egrep = "egrep --color=auto";
          jctl = "journalctl -p 3 -xb";
          please = "sudo";

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
            body = ''
              set count (count $argv | tr -d \n)
              if test "$count" = 2; and test -d "$argv[1]"
                  set from (echo $argv[1] | trim-right /)
                  set to (echo $argv[2])
                  command cp -r $from $to
              else
                  command cp $argv
              end
            '';
          };
        };

        interactiveShellInit = ''
          set -gx EDITOR nvim
          set -gx VISUAL nvim

          # Render man pages through bat.
          set -x MANROFFOPT "-c"
          set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

          # Tune the done plugin: only notify for commands past 10s, at low urgency.
          set -g __done_min_cmd_duration 10000
          set -g __done_notification_urgency_level low

          # Prepend ~/.local/bin to PATH when it exists.
          if test -d ~/.local/bin
              fish_add_path ~/.local/bin
          end

          # Apply fish-compatible profile overrides if present.
          if test -f ~/.fish_profile
              source ~/.fish_profile
          end
        '';
      };
    };
  };
}
