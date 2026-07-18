set -gx EDITOR nvim
set -gx VISUAL nvim

# Render man pages through bat.
set -x MANROFFOPT "-c"
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
