# dotfiles

Dotfiles managed as a bare git repo checked out over `$HOME`, for machines
running CachyOS with KDE Plasma. 

## Bootstrapping a new machine

```sh
mkdir -p ~/.config/fish/functions
curl -fsSL https://git.alexion.dev/alexion/dotfiles/raw/branch/main/.config/fish/functions/dot.fish \
    -o ~/.config/fish/functions/dot.fish
fish -c 'dot init'
```

## Commands

| Command                 | Description                                                                              |
| ----------------------- | ----------------------------------------------------------------------------------------- |
| `dot help`              | Lists available commands.                                                                |
| `dot init`              | Bootstraps the dotfiles repo on a new machine.                                           |
| `dot install <pkgs>`    | Installs the given pacman packages and appends them to the tracked list (`~/.config/dot/packages/pacman`). |
| `dot install --restore` | Reinstalls every package from the tracked list.                                          |
| `dot kde help`          | Lists `dot kde`'s subcommands.                                                           |
| `dot kde save <identifier>` | Reads a KDE setting's current live value and declares it in the manifest (`~/.config/dot/kde-manifest`). |
| `dot kde save`          | Refreshes every already-declared manifest entry's value from the live system.            |
| `dot <git>`             | Everything else is passed to `git`.                                                      |

See [CLAUDE.md](../.config/dot/CLAUDE.md) for the `dot` tool's internal
architecture, bootstrap logic, subcommand dispatch, and test suite.

## Keybindings

See [keybindings.md](keybindings.md) for custom and useful default
keybindings across configured tools (currently: tmux).
