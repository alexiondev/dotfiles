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
