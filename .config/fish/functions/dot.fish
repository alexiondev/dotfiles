function dot --wraps=git --description 'Manage dotfiles via a bare repo checked out over $HOME'
    set -l dotfiles_dir $HOME/.dotfiles

    if test "$argv[1]" = init
        set -e argv[1]
        __dot_init $dotfiles_dir $argv
        return $status
    end

    if test "$argv[1]" = help
        __dot_help
        return $status
    end

    set -l commands_dir $HOME/.config/dot/commands
    set -l command_file $commands_dir/$argv[1].fish
    set -l nested_command_file $commands_dir/$argv[1]/$argv[1].fish

    if test -n "$argv[1]"
        if test -f "$command_file"
            source $command_file
            _dot_$argv[1] $argv[2..-1]
            return $status
        else if test -f "$nested_command_file"
            source $nested_command_file
            _dot_$argv[1] $argv[2..-1]
            return $status
        end
    end

    git --git-dir=$dotfiles_dir --work-tree=$HOME $argv
end

# Kept inline (not a separate autoloaded function file) because this is the
# only subcommand that must work before the dotfiles repo has been cloned.
function __dot_init
    set -l dotfiles_dir $argv[1]
    set -e argv[1]

    argparse 'url=' -- $argv
    or return 1

    set -l url $_flag_url
    test -n "$url"; or set url ssh://gitea@git.alexion.dev:2022/alexion/dotfiles.git

    if test -e $dotfiles_dir
        echo "dot init: $dotfiles_dir already exists, refusing to re-initialize" >&2
        return 1
    end

    git clone --bare $url $dotfiles_dir
    or begin
        echo "dot init: failed to clone $url" >&2
        return 1
    end

    git --git-dir=$dotfiles_dir config status.showUntrackedFiles no

    set -l checkout_output (git --git-dir=$dotfiles_dir --work-tree=$HOME checkout 2>&1)
    set -l checkout_status $status

    if test $checkout_status -ne 0
        set -l conflicts
        set -l in_block 0

        for line in $checkout_output
            if test $in_block -eq 1
                if string match -rq '^\s' -- $line
                    set -a conflicts (string trim -- $line)
                    continue
                else
                    set in_block 0
                end
            end

            string match -q '*would be overwritten by checkout:*' -- $line
            and set in_block 1
        end

        if test (count $conflicts) -eq 0
            echo "dot init: checkout failed and no recoverable conflicts were found:" >&2
            printf '%s\n' $checkout_output >&2
            return 1
        end

        set -l backup_dir $HOME/.dotfiles-backup/(date +%Y%m%dT%H%M%S)
        for f in $conflicts
            mkdir -p (path dirname $backup_dir/$f)
            mv $HOME/$f $backup_dir/$f
            echo "dot init: backed up ~/$f to $backup_dir/$f"
        end

        git --git-dir=$dotfiles_dir --work-tree=$HOME checkout
        or begin
            echo "dot init: checkout still failing after backing up conflicts, aborting" >&2
            return 1
        end
    end

    echo "dot init: bootstrapped $dotfiles_dir from $url"
end

# The custom-subcommand glob is duplicated (not shared with
# completions/dot.fish) because fish only autoloads a function from a file
# named after that function; a shared helper would go undefined if `dot help`
# ran in a completion context before `dot` itself had ever been sourced.
function __dot_help
    echo "dot: manage dotfiles via a bare repo checked out over \$HOME

Commands:
  init    bootstrap the dotfiles repo on a new machine
  help    show this message"

    for f in $HOME/.config/dot/commands/*.fish
        test -e $f; or continue
        echo "  "(path basename $f | path change-extension '')
    end

    for d in $HOME/.config/dot/commands/*/
        test -d $d; or continue
        set -l name (path basename $d)
        test -f $d$name.fish; or continue
        echo "  $name"
    end

    echo "
Run 'dot <command> help' for flags on a specific command.

Any other command is passed through to git (dot status, dot add, dot commit, dot push, ...)."
end
