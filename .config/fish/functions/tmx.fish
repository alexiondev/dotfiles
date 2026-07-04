function tmx --description 'Attach to a tmux session, creating it if needed'
    tmux new-session -A -s $argv[1]
end
