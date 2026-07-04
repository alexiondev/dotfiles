function dot --wraps=git --description 'Manage dotfiles via a bare repo checked out over $HOME'
    set -l dotfiles_dir $HOME/.dotfiles

    if test "$argv[1]" = init
        set -e argv[1]
        __dot_init $dotfiles_dir $argv
        return $status
    end

    set -l commands_dir $HOME/.config/dot/commands
    set -l command_file $commands_dir/$argv[1].fish

    if test -n "$argv[1]" -a -f "$command_file"
        source $command_file
        _dot_$argv[1] $argv[2..-1]
        return $status
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
