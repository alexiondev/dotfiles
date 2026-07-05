function _dot_kde_usage
    echo "usage: dot kde <command>

Commands:
  apply   push manifest entries onto the live system
  save    write live KDE settings into the manifest
  help    show this message

Run 'dot kde <command> help' for flags on a specific command."
end

function _dot_kde
    if test "$argv[1]" = help
        _dot_kde_usage
        return 0
    end

    set -l helper_dir (status dirname)

    switch "$argv[1]"
        case apply
            python3 $helper_dir/kde.py apply $argv[2..-1]
            return $status
        case save
            python3 $helper_dir/kde.py save $argv[2..-1]
            return $status
        case '*'
            _dot_kde_usage
            return 1
    end
end
