function _dot_install_usage
    echo "usage: dot install [--restore] [--no-sync] [package ...]
  --restore   reinstall every package from the tracked list
  --no-sync   skip 'pacman -Sy' before installing"
end

function _dot_install
    if test "$argv[1]" = help
        _dot_install_usage
        return 0
    end

    argparse 'restore' 'no-sync' -- $argv
    or return 1

    set -l list_dir $HOME/.config/dot/packages
    set -l list_file $list_dir/pacman
    set -l packages

    if set -q _flag_restore
        if test (count $argv) -gt 0
            echo "dot install: --restore cannot be combined with package names" >&2
            return 1
        end

        if not test -s $list_file
            echo "dot install: no package list found at $list_file" >&2
            return 1
        end

        set packages (cat $list_file)
    else
        if test (count $argv) -eq 0
            echo "dot install: no packages given (use --restore to reinstall from the list)" >&2
            return 1
        end

        set packages $argv
    end

    if not set -q _flag_no_sync
        sudo pacman -Sy
        or return 1
    end

    sudo pacman -S --needed $packages
    or return 1

    if set -q _flag_restore
        return 0
    end

    mkdir -p $list_dir
    test -f $list_file
    or touch $list_file

    printf '%s\n' $packages >>$list_file
    sort -u -o $list_file $list_file
end
