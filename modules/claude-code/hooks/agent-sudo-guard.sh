#!/bin/sh
# agent-sudo-guard.sh — refuse a privileged command while sudo's credential
# cache is cold, naming the command that warms it.
#
# Commands arrive here from subprocesses holding no terminal, so an uncached
# sudo fails with a bare non-zero exit and no output, reading as an unexplained
# stall. The probe below reads a cache keyed per user rather than per terminal,
# so an authentication made in the operator's own terminal counts.

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Anchored to a command position so a `sudo` appearing as an argument or inside
# a string does not trip the guard.
if ! printf '%s' "$command" | grep -qE '(^|[;&|(]|&&|\|\|)[[:space:]]*sudo([[:space:]]|$)'; then
	exit 0
fi

if sudo -n true 2>/dev/null; then
	exit 0
fi

# Exit 2 blocks the call and feeds stderr back to the agent.
echo 'Blocked: sudo has no cached credential, and this command cannot answer a password prompt.
Ask the operator to run `sudo -v` in their own terminal, then retry.
Never attempt to supply a password directly.
If this still blocks immediately after the operator runs `sudo -v`, the cache is
not the cause: check that this hook can reach sudo at all.' >&2
exit 2
