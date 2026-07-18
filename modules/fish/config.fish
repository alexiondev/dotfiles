# vi-style modal editing on the command line.
set -g fish_key_bindings fish_vi_key_bindings

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
