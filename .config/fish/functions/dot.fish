function dot --wraps=git --description 'Manage dotfiles via a bare repo checked out over $HOME'
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME $argv
end
complete -c dot -w git
