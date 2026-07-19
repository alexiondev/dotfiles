#!/bin/sh
# attention-bell.sh — ring the terminal bell in this Claude session's tmux pane
# so tmux's monitor-bell flags the (background) window red in the status bar.
#
# Claude Code runs hooks as detached subprocesses: they have no controlling
# terminal, so /dev/tty is unavailable here. But the parent-process chain up to
# the `claude` process stays intact, and `claude` itself holds the pane's pty.
# So we walk ancestry to find it and write the bell straight to that tty.
# (Writing a bare BEL to an explicit /dev/pts/N works even from a detached
# process — verified against tmux's window_bell_flag.)

pid=$PPID
while [ "$pid" -gt 1 ] 2>/dev/null; do
	if [ "$(ps -o comm= -p "$pid" 2>/dev/null)" = claude ]; then
		tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
		[ -n "$tty" ] && [ "$tty" != '?' ] && printf '\a' > "/dev/$tty"
		exit 0
	fi
	pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
	[ -z "$pid" ] && break
done
