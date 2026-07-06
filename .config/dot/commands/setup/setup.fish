function _dot_setup_usage
    echo "usage: dot setup [<task>]

Tasks:
  folders   bring the 8 standard XDG user directories under the short-name convention
  help      show this message

Run 'dot setup <task> help' for details on a specific task.

With no task given, runs every setup task."
end

function _dot_setup
    if test "$argv[1]" = help
        _dot_setup_usage
        return 0
    end

    set -l helper_dir (status dirname)
    source $helper_dir/folders.fish

    if test -z "$argv[1]"
        _dot_setup_folders
        return $status
    end

    switch $argv[1]
        case folders
            _dot_setup_folders $argv[2..-1]
            return $status
        case '*'
            _dot_setup_usage
            return 1
    end
end
