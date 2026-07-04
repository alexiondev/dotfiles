# dotfiles

Managed as a bare git repo checked out over `$HOME`. Not cloned in the usual
sense — `git --git-dir=~/.dotfiles --work-tree=$HOME` treats `$HOME` itself as
the working tree.

## Everyday use

A fish function named `dot` wraps that invocation:

```fish
dot status
dot add .bashrc
dot commit -m 'update bashrc'
dot push
```

Any git subcommand works — `dot` forwards whatever you type straight to git.

## Bootstrapping a new machine

Before `dot` exists there's nothing to autoload it from, so the very first
step is fetching that one file by hand:

```sh
mkdir -p ~/.config/fish/functions
curl -fsSL https://git.alexion.dev/alexion/dotfiles/raw/branch/main/.config/fish/functions/dot.fish \
    -o ~/.config/fish/functions/dot.fish
fish -c 'dot init'
```

`dot init`:

- clones the bare repo to `~/.dotfiles`
- backs up any pre-existing files that would be overwritten by checkout into
  `~/.dotfiles-backup/<timestamp>/`
- checks out the tracked files onto `$HOME`
- sets `status.showUntrackedFiles=no` so `dot status` doesn't list all of
  `$HOME`

It refuses to run if `~/.dotfiles` already exists, and it never falls back to
creating a fresh empty repo if the clone fails.

## Adding new subcommands

Beyond `init`, `dot` looks for `~/.config/dot/commands/<name>.fish`. Each file
should define a `_dot_<name>` function; `dot <name> args...` sources the file
and calls it. These files are deliberately *not* under
`~/.config/fish/functions/`, so they never become independently invokable
commands or clutter tab-completion outside of `dot` itself.

`~/.config/fish/completions/dot.fish` discovers them automatically by
scanning that directory, so a new command file gets tab-completion for free.
