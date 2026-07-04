# Keybindings

Quick reference for custom and useful default keybindings, so they don't have
to be re-discovered or looked up per tool.

Comma-separated keys are pressed in sequence, not together.

| Key                                                   | Context | Action                                             |
| ----------------------------------------------------- | ------- | -------------------------------------------------- |
| `Ctrl` + `Space`, `\`                                 | tmux    | Split side-by-side, opens in current directory     |
| `Ctrl` + `Space`, `-`                                 | tmux    | Split stacked, opens in current directory          |
| `Ctrl` + `Space`, `h` / `j` / `k` / `l`               | tmux    | Move focus left / down / up / right                |
| `Ctrl` + `Space`, `z`                                 | tmux    | Zoom/unzoom pane to fullscreen                     |
| `Ctrl` + `Space`, `o`                                 | tmux    | Cycle focus to next pane                           |
| `Ctrl` + `Space`, `x`                                 | tmux    | Kill current pane (asks to confirm)                |
| `Ctrl` + `Space`, `Ctrl` + `Up`/`Down`/`Left`/`Right` | tmux    | Resize pane                                        |
| `Ctrl` + `Space`, `c`                                 | tmux    | New window, opens in current directory             |
| `Ctrl` + `Space`, `0`-`9`                             | tmux    | Jump to window by number                           |
| `Ctrl` + `Space`, `n` / `p`                           | tmux    | Next / previous window                             |
| `Ctrl` + `Space`, `w`                                 | tmux    | Interactive window list                            |
| `Ctrl` + `Space`, `,`                                 | tmux    | Rename current window                              |
| `Ctrl` + `Space`, `&`                                 | tmux    | Kill current window (asks to confirm)              |
| `Ctrl` + `Space`, `[`                                 | tmux    | Enter copy mode                                    |
| `Ctrl` + `Space`, `]`                                 | tmux    | Paste most recent copy                             |
| `h` / `j` / `k` / `l`                                 | tmux    | Move cursor                                        |
| `v`                                                   | tmux    | Begin selection                                    |
| `y`                                                   | tmux    | Copy selection to system clipboard, exit copy mode |
| `/` / `?`                                             | tmux    | Search forward / backward                          |
| `q`                                                   | tmux    | Exit copy mode                                     |
| `Ctrl` + `Space`, `d`                                 | tmux    | Detach from session                                |
| `Ctrl` + `Space`, `$`                                 | tmux    | Rename session                                     |
| `Ctrl` + `Space`, `s`                                 | tmux    | Interactive session list                           |
| `Ctrl` + `Space`, `(` / `)`                           | tmux    | Switch to previous / next session                  |
| `Ctrl` + `Space`, `r`                                 | tmux    | Reload `tmux.conf`                                 |
| `Ctrl` + `h` / `j` / `k` / `l`                        | neovim  | Move focus between splits left / down / up / right |
| `Esc`                                                  | neovim  | Clear search highlight                             |
| `Space`, `e`                                           | neovim  | Toggle file explorer (netrw)                       |
