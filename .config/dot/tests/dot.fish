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
