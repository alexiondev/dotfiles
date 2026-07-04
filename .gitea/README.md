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

| Command     | Description                                     |
| ----------- | ----------------------------------------------- |
| `dot help`  | Lists available commands.                       |
| `dot init`  | Bootstraps the dotfiles repo on a new machine.  |
| `dot <git>` | Everything else is passed to `git`.             |

See [DOT-CLI.md](../.claude/skills/dotfiles/DOT-CLI.md) for the `dot` tool's
internal architecture, bootstrap logic, subcommand dispatch, and test suite.
