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

# --- dot kde ---
# The fixture schema directory stands in for the real /usr/share/config.kcfg:
# testrc.kcfg declares a plain <kcfgfile name="testrc">, kwin.kcfg declares
# <kcfgfile arg="true"> (resolved only via the hand-maintained exceptions
# list, kwin.kcfg -> kwinrc), and unmapped.kcfg is an arg="true" schema with
# no exceptions-list entry, so it never resolves to anything.
set -l kcfg_fixtures (path resolve (status dirname)/fixtures/kcfg)
set -gx DOT_KDE_KCFG_DIR $kcfg_fixtures

# kreadconfig6 itself is never mocked for the tests that exercise real
# save behavior (per the project's convention, it runs for real against
# fixture rc files under the scratch HOME) -- only the help-path tests below
# swap in a logging fake, to prove kreadconfig6 is never invoked for them.
set -l path_before_fake_kreadconfig $PATH

# --- dot kde help / dot kde save help touch neither the manifest nor kreadconfig6 ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/kde
cp $commands_dir/kde/kde.fish $HOME/.config/dot/commands/kde/kde.fish
cp $commands_dir/kde/kde.py $HOME/.config/dot/commands/kde/kde.py

set -l fake_bin_kde (mktemp -d)
set -gx KREADCONFIG_LOG (mktemp)
echo '#!/bin/sh
echo "$@" >>"$KREADCONFIG_LOG"
exit 1' >$fake_bin_kde/kreadconfig6
chmod +x $fake_bin_kde/kreadconfig6
set -gx PATH $fake_bin_kde $PATH

set -l kde_help_output (dot kde help)
set -l kde_help_status $status
set -l kreadconfig_called_for_kde_help (test -s $KREADCONFIG_LOG; and echo yes; or echo no)
set -l manifest_exists_after_kde_help (test -e $HOME/.config/dot/kde-manifest; and echo yes; or echo no)

@test "dot kde help succeeds" $kde_help_status -eq 0
@test "dot kde help mentions save" (string match -q '*save*' -- $kde_help_output; echo $status) -eq 0
@test "dot kde help never invokes kreadconfig6" $kreadconfig_called_for_kde_help = no
@test "dot kde help does not create a manifest" $manifest_exists_after_kde_help = no

set -l kde_save_help_output (dot kde save help)
set -l kde_save_help_status $status
set -l kreadconfig_called_for_save_help (test -s $KREADCONFIG_LOG; and echo yes; or echo no)
set -l manifest_exists_after_save_help (test -e $HOME/.config/dot/kde-manifest; and echo yes; or echo no)

@test "dot kde save help succeeds" $kde_save_help_status -eq 0
@test "dot kde save help mentions identifier" (string match -q '*identifier*' -- $kde_save_help_output; echo $status) -eq 0
@test "dot kde save help never invokes kreadconfig6" $kreadconfig_called_for_save_help = no
@test "dot kde save help does not create a manifest" $manifest_exists_after_save_help = no

set -gx PATH $path_before_fake_kreadconfig

# --- dot kde save <identifier>: declares a new manifest entry from the real live value ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/kde
cp $commands_dir/kde/kde.fish $HOME/.config/dot/commands/kde/kde.fish
cp $commands_dir/kde/kde.py $HOME/.config/dot/commands/kde/kde.py
mkdir -p $HOME/.config
printf '[General]\nGreeting=Hi=There\n' >$HOME/.config/testrc
set -l manifest $HOME/.config/dot/kde-manifest

dot kde save testrc.General.Greeting >/dev/null 2>&1
set -l save_status $status

@test "dot kde save <identifier> succeeds" $save_status -eq 0
@test "declares the identifier with its live value, preserving an embedded '='" (cat $manifest | string collect) = "testrc.General.Greeting=Hi=There"

# a kcfg entry whose ini key (key=) differs from its schema name still
# resolves correctly, falling back to the schema default when unset live
dot kde save testrc.General.RealKey >/dev/null 2>&1
@test "resolves an aliased kcfg key (name != key) to its schema default" (string match -q '*testrc.General.RealKey=AliasDefault*' -- (cat $manifest); echo $status) -eq 0

# the identifier is split on the first two dots only, so the key portion
# may itself contain further dots and spaces
dot kde save "testrc.General.Some.Key With Spaces" >/dev/null 2>&1
@test "an identifier's key portion may contain further dots and spaces" (string match -q '*testrc.General.Some.Key With Spaces=SpacedDefault*' -- (cat $manifest); echo $status) -eq 0

# an arg="true" schema resolves through the hand-maintained exceptions list
# (kwin.kcfg -> kwinrc), not by scanning for a static <kcfgfile name>
dot kde save kwinrc.Windows.BorderSize >/dev/null 2>&1
@test "resolves an arg=true schema via the hand-maintained exceptions list" (string match -q '*kwinrc.Windows.BorderSize=Normal*' -- (cat $manifest); echo $status) -eq 0

set -l declared_count_before_freeform (cat $manifest | count)

# a setting whose rc file never appears in the mapping table falls to the
# freeform branch, which the dispatch structure accounts for but does not
# implement yet
dot kde save somefreeform.Group.Key >/dev/null 2>&1
set -l unmapped_status $status
set -l declared_count_after_freeform (cat $manifest | count)

@test "an unmapped rc file is not silently treated as schema-backed" $unmapped_status -ne 0
@test "a rejected freeform save adds no manifest entry" $declared_count_after_freeform -eq $declared_count_before_freeform

# an arg="true" schema *absent* from the exceptions list (unmapped.kcfg)
# must not be guessed at (e.g. from its own filename) -- it contributes
# nothing to the mapping table, so its settings fall to freeform too
dot kde save unmapped.Whatever.Setting >/dev/null 2>&1
set -l unlisted_arg_true_status $status
set -l declared_count_after_unlisted (cat $manifest | count)

@test "an arg=true schema missing from the exceptions list resolves to freeform, not schema" $unlisted_arg_true_status -ne 0
@test "a rejected unlisted-arg=true save adds no manifest entry" $declared_count_after_unlisted -eq $declared_count_before_freeform

# --- dot kde save with no arguments refreshes every already-declared entry ---
printf '[General]\nGreeting=Changed\n' >$HOME/.config/testrc
dot kde save >/dev/null 2>&1
set -l refresh_status $status
set -l declared_count_after_refresh (cat $manifest | count)

@test "dot kde save with no arguments succeeds" $refresh_status -eq 0
@test "refreshes an already-declared entry's value from the live system" (string match -q '*testrc.General.Greeting=Changed*' -- (cat $manifest); echo $status) -eq 0
@test "refresh leaves other already-declared entries untouched" (string match -q '*testrc.General.RealKey=AliasDefault*' -- (cat $manifest); echo $status) -eq 0
@test "refresh adds no new undeclared entries" $declared_count_after_refresh -eq $declared_count_before_freeform

# --- misuse: too many arguments / a malformed identifier ---
dot kde save one two >/dev/null 2>&1
set -l too_many_args_status $status
@test "dot kde save rejects more than one identifier" $too_many_args_status -ne 0

dot kde save nodots >/dev/null 2>&1
set -l bad_identifier_status $status
@test "dot kde save rejects an identifier without file.group.key structure" $bad_identifier_status -ne 0

# --- dot kde apply help touches neither the manifest nor kwriteconfig6 ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/kde
cp $commands_dir/kde/kde.fish $HOME/.config/dot/commands/kde/kde.fish
cp $commands_dir/kde/kde.py $HOME/.config/dot/commands/kde/kde.py

set -l fake_bin_kwrite (mktemp -d)
set -gx KWRITECONFIG_LOG (mktemp)
echo '#!/bin/sh
echo "$@" >>"$KWRITECONFIG_LOG"
exit 1' >$fake_bin_kwrite/kwriteconfig6
chmod +x $fake_bin_kwrite/kwriteconfig6
set -gx PATH $fake_bin_kwrite $path_before_fake_kreadconfig

set -l kde_apply_help_output (dot kde apply help)
set -l kde_apply_help_status $status
set -l kwriteconfig_called_for_apply_help (test -s $KWRITECONFIG_LOG; and echo yes; or echo no)
set -l manifest_exists_after_apply_help (test -e $HOME/.config/dot/kde-manifest; and echo yes; or echo no)

@test "dot kde apply help succeeds" $kde_apply_help_status -eq 0
@test "dot kde apply help mentions manifest" (string match -q '*manifest*' -- $kde_apply_help_output; echo $status) -eq 0
@test "dot kde apply help never invokes kwriteconfig6" $kwriteconfig_called_for_apply_help = no
@test "dot kde apply help does not create a manifest" $manifest_exists_after_apply_help = no

set -gx PATH $path_before_fake_kreadconfig

# --- dot kde apply: pushes every declared manifest entry onto the live rc file ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/kde
cp $commands_dir/kde/kde.fish $HOME/.config/dot/commands/kde/kde.fish
cp $commands_dir/kde/kde.py $HOME/.config/dot/commands/kde/kde.py
mkdir -p $HOME/.config/dot
printf 'testrc.General.Greeting=Applied Greeting\ntestrc.General.RealKey=Hi=There\n' >$HOME/.config/dot/kde-manifest

dot kde apply >/dev/null 2>&1
set -l apply_status $status
set -l testrc_after_apply (cat $HOME/.config/testrc)

@test "dot kde apply succeeds" $apply_status -eq 0
@test "dot kde apply writes a declared value onto the live rc file" (string match -q '*Greeting=Applied Greeting*' -- $testrc_after_apply; echo $status) -eq 0
@test "dot kde apply preserves an embedded '=' in the applied value" (string match -q '*RealKey=Hi=There*' -- $testrc_after_apply; echo $status) -eq 0

# re-running against a system already matching the manifest changes nothing
dot kde apply >/dev/null 2>&1
set -l reapply_status $status
set -l testrc_after_reapply (cat $HOME/.config/testrc)

@test "re-running dot kde apply succeeds" $reapply_status -eq 0
@test "re-running dot kde apply against an already-applied system is idempotent" "$testrc_after_reapply" = "$testrc_after_apply"

# a manifest entry whose rc file isn't schema-backed (freeform, not yet
# implemented) is rejected rather than silently mis-applied
printf 'testrc.General.Greeting=Applied Greeting\nsomefreeform.Group.Key=Value\n' >$HOME/.config/dot/kde-manifest
dot kde apply >/dev/null 2>&1
set -l apply_freeform_status $status
@test "dot kde apply rejects a manifest entry whose mechanism isn't schema-backed yet" $apply_freeform_status -ne 0

# misuse: apply takes no arguments
printf 'testrc.General.Greeting=Applied Greeting\n' >$HOME/.config/dot/kde-manifest
dot kde apply extra-arg >/dev/null 2>&1
set -l apply_extra_arg_status $status
@test "dot kde apply rejects an unexpected argument" $apply_extra_arg_status -ne 0

# --- dot kde diff help touches neither the manifest nor kreadconfig6 ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/kde
cp $commands_dir/kde/kde.fish $HOME/.config/dot/commands/kde/kde.fish
cp $commands_dir/kde/kde.py $HOME/.config/dot/commands/kde/kde.py

set -l fake_bin_kde_diff (mktemp -d)
set -gx KREADCONFIG_LOG (mktemp)
echo '#!/bin/sh
echo "$@" >>"$KREADCONFIG_LOG"
exit 1' >$fake_bin_kde_diff/kreadconfig6
chmod +x $fake_bin_kde_diff/kreadconfig6
set -gx PATH $fake_bin_kde_diff $path_before_fake_kreadconfig

set -l kde_diff_help_output (dot kde diff help)
set -l kde_diff_help_status $status
set -l kreadconfig_called_for_diff_help (test -s $KREADCONFIG_LOG; and echo yes; or echo no)
set -l manifest_exists_after_diff_help (test -e $HOME/.config/dot/kde-manifest; and echo yes; or echo no)

@test "dot kde diff help succeeds" $kde_diff_help_status -eq 0
@test "dot kde diff help mentions undeclared" (string match -q '*undeclared*' -- $kde_diff_help_output; echo $status) -eq 0
@test "dot kde diff help never invokes kreadconfig6" $kreadconfig_called_for_diff_help = no
@test "dot kde diff help does not create a manifest" $manifest_exists_after_diff_help = no

set -gx PATH $path_before_fake_kreadconfig

# --- dot kde diff: broad read-only scan over every schema-backed identifier,
#     tagging each mismatch declared/undeclared, and skipping settings that
#     already match their schema default ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/kde
cp $commands_dir/kde/kde.fish $HOME/.config/dot/commands/kde/kde.fish
cp $commands_dir/kde/kde.py $HOME/.config/dot/commands/kde/kde.py
mkdir -p $HOME/.config/dot

# Greeting differs from its default and is already declared in the manifest;
# RealKey differs from its default but has never been declared; Some.Key With
# Spaces is left unset, so it falls back to (and matches) its schema default,
# and kwinrc.Windows.BorderSize likewise matches its default via the
# arg=true/exceptions-list mapping -- neither should be reported.
printf '[General]\nGreeting=Bonjour\nRealKey=ChangedAlias\n' >$HOME/.config/testrc
printf 'testrc.General.Greeting=Bonjour\n' >$HOME/.config/dot/kde-manifest
set -l manifest_before_diff (cat $HOME/.config/dot/kde-manifest | string collect)

set -l diff_output (dot kde diff)
set -l diff_status $status
set -l manifest_after_diff (cat $HOME/.config/dot/kde-manifest | string collect)

@test "dot kde diff succeeds" $diff_status -eq 0
@test "dot kde diff tags an already-declared mismatch as declared" (string match -q '*declared testrc.General.Greeting = Bonjour (default: Hello)*' -- $diff_output; echo $status) -eq 0
@test "dot kde diff tags a never-declared mismatch as undeclared" (string match -q '*undeclared testrc.General.RealKey = ChangedAlias (default: AliasDefault)*' -- $diff_output; echo $status) -eq 0
@test "dot kde diff does not report a setting matching its default (unset key)" (string match -q '*Some.Key With Spaces*' -- $diff_output; echo $status) -eq 1
@test "dot kde diff does not report a setting matching its default (arg=true mapping)" (string match -q '*BorderSize*' -- $diff_output; echo $status) -eq 1
@test "dot kde diff makes no writes to the manifest" "$manifest_after_diff" = "$manifest_before_diff"

dot kde diff extra-arg >/dev/null 2>&1
set -l diff_extra_arg_status $status
@test "dot kde diff rejects an unexpected argument" $diff_extra_arg_status -ne 0

# --- kde.py complete: tab-completion candidates, sourced from the live
#     schema mapping table rather than a hardcoded list. This is the
#     underlying data completions/dot.fish shells out to; the fish
#     completion wiring itself is verified manually (no existing
#     infrastructure tests completions at all, per the nested-subcommand
#     prefactoring task) ---
set -l complete_output (python3 $HOME/.config/dot/commands/kde/kde.py complete)

@test "kde.py complete lists a schema-backed identifier" (string match -q '*testrc.General.Greeting*' -- $complete_output; echo $status) -eq 0
@test "kde.py complete resolves an aliased kcfg key to its ini key, not its schema name" (string match -q '*testrc.General.RealKey*' -- $complete_output; echo $status) -eq 0
@test "kde.py complete lists an arg=true schema resolved via the exceptions list" (string match -q '*kwinrc.Windows.BorderSize*' -- $complete_output; echo $status) -eq 0
@test "kde.py complete never lists an aliased entry under its schema name" (string match -q '*testrc.General.AliasedKey*' -- $complete_output; echo $status) -eq 1
@test "kde.py complete never lists an arg=true schema absent from the exceptions list" (string match -q '*Whatever.Setting*' -- $complete_output; echo $status) -eq 1

# --- dot help / dot help discovers dot kde ---
set -l help_with_kde (dot help)
@test "dot help lists the kde subcommand" (string match -q '*kde*' -- $help_with_kde; echo $status) -eq 0
