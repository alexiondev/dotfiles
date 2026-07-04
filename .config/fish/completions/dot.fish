function __dot_custom_subcommands
    echo init
    echo help
    path basename $HOME/.config/dot/commands/*.fish 2>/dev/null | path change-extension ''
end

complete -c dot -n __fish_use_subcommand -a "(__dot_custom_subcommands)"
