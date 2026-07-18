source /usr/share/cachyos-fish-config/cachyos-config.fish

set -gx EDITOR nvim
set -gx VISUAL nvim

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# Pi
fish_add_path "/home/alexion/.local/opt/node-v24.18.0-linux-x64/bin"
