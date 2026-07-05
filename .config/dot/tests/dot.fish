set -l commands_dir (path resolve (status dirname)/../commands)

# Fixture: a fake bare "remote" repo with tracked dotfiles, shared read-only
# across every case below. dot init only ever clones from it, never mutates it.
set -l remote (mktemp -d)/dotfiles.git
git init -q --bare $remote

set -l seed (mktemp -d)
pushd $seed
git init -q -b main
git config user.email test@dot.fish
git config user.name dot-tests
mkdir -p .config/fish/functions
echo 'echo tracked-bashrc' >.bashrc
echo 'echo hi' >.config/fish/functions/greet.fish
git add -A
git commit -qm seed >/dev/null
git remote add origin $remote
git push -q origin HEAD:main >/dev/null 2>&1
popd
git --git-dir=$remote symbolic-ref HEAD refs/heads/main

# --- fresh bootstrap, no conflicts ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
set -l fresh_status $status

@test "dot init succeeds against a clean HOME" $fresh_status -eq 0
@test "clones the bare repo to ~/.dotfiles" -e $HOME/.dotfiles
@test "checks out tracked files onto HOME" -e $HOME/.bashrc
@test "checked-out file has the repo's content" (cat $HOME/.bashrc) = "echo tracked-bashrc"
@test "disables status.showUntrackedFiles" (git --git-dir=$HOME/.dotfiles config --local status.showuntrackedfiles) = no

dot init --url $remote >/dev/null 2>&1
set -l repeat_status $status
@test "re-running dot init refuses when already initialized" $repeat_status -eq 1

set -l passthrough_status (dot status >/dev/null 2>&1; echo $status)
@test "git passthrough still works (dot status)" $passthrough_status -eq 0

# --- a pre-existing conflicting file gets backed up, not clobbered ---
set -gx HOME (mktemp -d)
echo 'pre-existing-content' >$HOME/.bashrc
dot init --url $remote >/dev/null 2>&1
set -l conflict_status $status

@test "dot init still succeeds with a conflicting file present" $conflict_status -eq 0
@test "conflicting file ends up with the tracked content" (cat $HOME/.bashrc) = "echo tracked-bashrc"
@test "a backup directory was created" -d $HOME/.dotfiles-backup
@test "the pre-existing content was preserved in the backup" (cat $HOME/.dotfiles-backup/*/.bashrc) = "pre-existing-content"

# --- an unreachable URL never falls back to creating an empty repo ---
set -gx HOME (mktemp -d)
dot init --url /nonexistent/path.git >/dev/null 2>&1
set -l bad_url_status $status
set -l dotfiles_exists (test -e $HOME/.dotfiles; and echo yes; or echo no)

@test "dot init fails on an unreachable URL" $bad_url_status -eq 1
@test "no .dotfiles directory is left behind on failure" $dotfiles_exists = no

# --- dispatches to files under ~/.config/dot/commands/ without polluting
#     the fish function namespace: the file only defines _dot_<name>, which
#     only becomes known to fish once dot sources it on demand.
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1

mkdir -p $HOME/.config/dot/commands
set -l marker (mktemp)
echo "function _dot_mark
    echo marked >$marker
end" >$HOME/.config/dot/commands/mark.fish

dot mark >/dev/null 2>&1
@test "dispatches to a command file under ~/.config/dot/commands/" (cat $marker) = marked

# --- dispatches to a nested commands/<name>/<name>.fish, same as a flat file
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1

mkdir -p $HOME/.config/dot/commands/nested
set -l nested_marker (mktemp)
echo "function _dot_nested
    echo nested-marked >$nested_marker
end" >$HOME/.config/dot/commands/nested/nested.fish

dot nested >/dev/null 2>&1
@test "dispatches to a nested commands/<name>/<name>.fish" (cat $nested_marker) = nested-marked

# --- dot help ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1

set -l help_output (dot help)
set -l help_status $status

@test "dot help succeeds" $help_status -eq 0
@test "dot help lists init" (string match -q '*init*' -- $help_output; echo $status) -eq 0
@test "dot help mentions git passthrough" (string match -q '*git*' -- $help_output; echo $status) -eq 0
@test "dot help hints at per-command help" (string match -q "*dot <command> help*" -- $help_output; echo $status) -eq 0

mkdir -p $HOME/.config/dot/commands
echo "function _dot_mark
    echo marked
end" >$HOME/.config/dot/commands/mark.fish

set -l help_with_custom (dot help)
@test "dot help lists custom commands found under ~/.config/dot/commands/" (string match -q '*mark*' -- $help_with_custom; echo $status) -eq 0

mkdir -p $HOME/.config/dot/commands/nested
echo "function _dot_nested
    echo nested
end" >$HOME/.config/dot/commands/nested/nested.fish

set -l help_with_nested (dot help)
@test "dot help lists a nested-directory subcommand" (string match -q '*nested*' -- $help_with_nested; echo $status) -eq 0

# --- dot install ---
# pacman and sudo are faked out via a bin dir prepended to PATH: sudo just
# execs its arguments, and pacman logs each invocation to $PACMAN_LOG (one
# line per call) and fails only when asked to install a package literally
# named "failpkg", so tests can force the failure path without touching the
# real package manager.
set -l fake_bin (mktemp -d)
echo '#!/bin/sh
exec "$@"' >$fake_bin/sudo
chmod +x $fake_bin/sudo

echo '#!/bin/sh
echo "$@" >>"$PACMAN_LOG"
for arg in "$@"; do
    if [ "$arg" = failpkg ]; then
        exit 1
    fi
done
exit 0' >$fake_bin/pacman
chmod +x $fake_bin/pacman

set -gx PATH $fake_bin $PATH

# --- a successful install records the packages, sorted and deduplicated ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands
cp $commands_dir/install.fish $HOME/.config/dot/commands/install.fish
set -gx PACMAN_LOG (mktemp)

dot install zeta alpha >/dev/null 2>&1
set -l first_install_status $status
set -l list_file $HOME/.config/dot/packages/pacman
set -l synced_by_default (string match -q '*-Sy*' -- (cat $PACMAN_LOG); and echo yes; or echo no)
set -l installed_named (string match -q '*-S --needed zeta alpha*' -- (cat $PACMAN_LOG); and echo yes; or echo no)

@test "dot install succeeds for real packages" $first_install_status -eq 0
@test "dot install syncs the database by default" $synced_by_default = yes
@test "dot install passes packages to pacman -S --needed" $installed_named = yes
@test "installed packages are recorded, sorted" (cat $list_file | string collect) = "alpha
zeta"

dot install beta >/dev/null 2>&1
@test "a later install merges into the existing list, still sorted" (cat $list_file | string collect) = "alpha
beta
zeta"

dot install alpha >/dev/null 2>&1
@test "re-installing an already-recorded package does not duplicate it" (cat $list_file | string collect) = "alpha
beta
zeta"

# --- --no-sync skips the database refresh ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands
cp $commands_dir/install.fish $HOME/.config/dot/commands/install.fish
set -gx PACMAN_LOG (mktemp)

dot install --no-sync somepkg >/dev/null 2>&1
set -l synced_with_no_sync (string match -q '*-Sy*' -- (cat $PACMAN_LOG); and echo yes; or echo no)
@test "--no-sync skips pacman -Sy" $synced_with_no_sync = no

# --- a failed pacman run records nothing ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands
cp $commands_dir/install.fish $HOME/.config/dot/commands/install.fish
set -gx PACMAN_LOG (mktemp)

dot install failpkg >/dev/null 2>&1
set -l failed_install_status $status
set -l list_exists_after_failure (test -e $HOME/.config/dot/packages/pacman; and echo yes; or echo no)

@test "dot install fails when pacman fails" $failed_install_status -ne 0
@test "a failed install leaves no package list behind" $list_exists_after_failure = no

# --- no packages and no --restore is a usage error ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands
cp $commands_dir/install.fish $HOME/.config/dot/commands/install.fish
set -gx PACMAN_LOG (mktemp)

dot install >/dev/null 2>&1
set -l no_args_status $status
set -l pacman_called_no_args (test -s $PACMAN_LOG; and echo yes; or echo no)

@test "dot install with no arguments and no --restore fails" $no_args_status -ne 0
@test "dot install with no arguments never calls pacman" $pacman_called_no_args = no

# --- --restore reinstalls everything from the list without rewriting it ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands
cp $commands_dir/install.fish $HOME/.config/dot/commands/install.fish
mkdir -p $HOME/.config/dot/packages
printf 'alpha\nbeta\n' >$HOME/.config/dot/packages/pacman
set -gx PACMAN_LOG (mktemp)

dot install --restore >/dev/null 2>&1
set -l restore_status $status
set -l restored_named (string match -q '*-S --needed alpha beta*' -- (cat $PACMAN_LOG); and echo yes; or echo no)

@test "dot install --restore succeeds" $restore_status -eq 0
@test "--restore installs every package from the list" $restored_named = yes
@test "--restore does not rewrite the list" (cat $HOME/.config/dot/packages/pacman | string collect) = "alpha
beta"

# --- --restore with no list yet is an error ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands
cp $commands_dir/install.fish $HOME/.config/dot/commands/install.fish
set -gx PACMAN_LOG (mktemp)

dot install --restore >/dev/null 2>&1
set -l restore_no_list_status $status

@test "--restore fails when no package list exists yet" $restore_no_list_status -ne 0

# --- --restore and explicit packages are mutually exclusive ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands
cp $commands_dir/install.fish $HOME/.config/dot/commands/install.fish
mkdir -p $HOME/.config/dot/packages
printf 'alpha\n' >$HOME/.config/dot/packages/pacman
set -gx PACMAN_LOG (mktemp)

dot install --restore extra >/dev/null 2>&1
set -l restore_conflict_status $status
set -l pacman_called_conflict (test -s $PACMAN_LOG; and echo yes; or echo no)

@test "--restore combined with package names fails" $restore_conflict_status -ne 0
@test "--restore combined with package names never calls pacman" $pacman_called_conflict = no

# --- help prints usage instead of touching pacman ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands
cp $commands_dir/install.fish $HOME/.config/dot/commands/install.fish
set -gx PACMAN_LOG (mktemp)

set -l help_output (dot install help)
set -l help_status $status
set -l pacman_called_help (test -s $PACMAN_LOG; and echo yes; or echo no)

@test "dot install help succeeds" $help_status -eq 0
@test "dot install help mentions --restore" (string match -q '*--restore*' -- $help_output; echo $status) -eq 0
@test "dot install help mentions --no-sync" (string match -q '*--no-sync*' -- $help_output; echo $status) -eq 0
@test "dot install help never calls pacman" $pacman_called_help = no
