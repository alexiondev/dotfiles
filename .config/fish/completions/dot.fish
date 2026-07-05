function __dot_custom_subcommands
    echo init
    echo help
    path basename $HOME/.config/dot/commands/*.fish 2>/dev/null | path change-extension ''

    for d in $HOME/.config/dot/commands/*/
        test -d $d; or continue
        set -l name (path basename $d)
        test -f $d$name.fish; or continue
        echo $name
    end
end

complete -c dot -n __fish_use_subcommand -a "(__dot_custom_subcommands)"

# --- dot install ---
complete -c dot -n "__fish_seen_subcommand_from install; and not __fish_seen_argument -l restore" -l restore -d "reinstall every package from the saved list"
complete -c dot -n "__fish_seen_subcommand_from install; and not __fish_seen_argument -l no-sync" -l no-sync -d "skip the pacman -Sy database refresh"
complete -c dot -n "__fish_seen_subcommand_from install; and not __fish_seen_argument -l restore" -f -a "(__fish_print_pacman_packages)"

# --- dot kde ---
complete -c dot -n "__fish_seen_subcommand_from kde; and not __fish_seen_subcommand_from save help" -f -a save -d "write live KDE settings into the manifest"
complete -c dot -n "__fish_seen_subcommand_from kde; and not __fish_seen_subcommand_from save help" -f -a help -d "show usage"
complete -c dot -n "__fish_seen_subcommand_from kde; and __fish_seen_subcommand_from save" -f -a help -d "show usage"
# Sourced live from the schema mapping table (real .kcfg files), not a
# hardcoded list -- same helper kde.py's own save/refresh logic builds from.
complete -c dot -n "__fish_seen_subcommand_from kde; and __fish_seen_subcommand_from save" -f -a "(python3 $HOME/.config/dot/commands/kde/kde.py complete 2>/dev/null)"
