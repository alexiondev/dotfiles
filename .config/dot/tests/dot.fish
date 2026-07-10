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
# freeform branch: read/write directly via kreadconfig6/kwriteconfig6, with
# "default" meaning "the key is absent" rather than any schema value
printf '[Group]\nKey=FreeformValue\n' >$HOME/.config/somefreeform
dot kde save somefreeform.Group.Key >/dev/null 2>&1
set -l freeform_save_status $status
set -l declared_count_after_freeform (cat $manifest | count)

@test "dot kde save succeeds for a freeform (unmapped rc file) identifier" $freeform_save_status -eq 0
@test "declares the freeform identifier with its real live value" (string match -q '*somefreeform.Group.Key=FreeformValue*' -- (cat $manifest); echo $status) -eq 0
@test "a freeform save adds exactly one manifest entry" $declared_count_after_freeform -eq (math $declared_count_before_freeform + 1)

# an arg="true" schema *absent* from the exceptions list (unmapped.kcfg)
# must not be guessed at (e.g. from its own filename) -- it contributes
# nothing to the mapping table, so its settings fall to freeform too. Proven
# here by reading with the key absent: a schema-backed read would fall back
# to the schema's declared default ("Unreachable"); freeform's "default" is
# instead "the key is absent", so it reads empty.
dot kde save unmapped.Whatever.Setting >/dev/null 2>&1
set -l unlisted_arg_true_status $status

@test "an arg=true schema missing from the exceptions list resolves to freeform, not schema" $unlisted_arg_true_status -eq 0
@test "a freeform read never falls back to another schema's default" (string match -q '*Unreachable*' -- (cat $manifest); echo $status) -eq 1
@test "a freeform read of an absent key stores an empty value" (string match -q '*unmapped.Whatever.Setting=*' -- (cat $manifest); echo $status) -eq 0

# the shortcuts mechanism (kglobalshortcutsrc -> kglobalaccel D-Bus calls) is
# deliberately excluded from this suite -- it depends on a live, already-running
# session service not practically substitutable without disproportionate mock
# infrastructure. Verified manually against the real session instead.

set -l declared_count_before_refresh (cat $manifest | count)

# --- dot kde save with no arguments refreshes every already-declared entry ---
printf '[General]\nGreeting=Changed\n' >$HOME/.config/testrc
printf '[Group]\nKey=RefreshedFreeform\n' >$HOME/.config/somefreeform
dot kde save >/dev/null 2>&1
set -l refresh_status $status
set -l declared_count_after_refresh (cat $manifest | count)

@test "dot kde save with no arguments succeeds" $refresh_status -eq 0
@test "refreshes an already-declared schema-backed entry's value from the live system" (string match -q '*testrc.General.Greeting=Changed*' -- (cat $manifest); echo $status) -eq 0
@test "refreshes an already-declared freeform entry's value from the live system" (string match -q '*somefreeform.Group.Key=RefreshedFreeform*' -- (cat $manifest); echo $status) -eq 0
@test "refresh leaves other already-declared entries untouched" (string match -q '*testrc.General.RealKey=AliasDefault*' -- (cat $manifest); echo $status) -eq 0
@test "refresh adds no new undeclared entries" $declared_count_after_refresh -eq $declared_count_before_refresh

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

# a manifest entry whose rc file has no schema (freeform) is written
# directly via kwriteconfig6, idempotently, just like a schema-backed entry
printf 'testrc.General.Greeting=Applied Greeting\nsomefreeform.Group.Key=Value\n' >$HOME/.config/dot/kde-manifest
dot kde apply >/dev/null 2>&1
set -l apply_freeform_status $status
set -l freeformrc_after_apply (cat $HOME/.config/somefreeform)

@test "dot kde apply succeeds for a manifest with a freeform entry" $apply_freeform_status -eq 0
@test "dot kde apply writes a freeform entry via kwriteconfig6" (string match -q '*Key=Value*' -- $freeformrc_after_apply; echo $status) -eq 0

dot kde apply >/dev/null 2>&1
set -l freeformrc_after_reapply (cat $HOME/.config/somefreeform)
@test "re-running dot kde apply against an already-applied freeform entry is idempotent" "$freeformrc_after_reapply" = "$freeformrc_after_apply"

# the shortcuts mechanism is deliberately excluded from this suite -- see the
# note by the `dot kde save` shortcuts exclusion above.

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
# arg=true/exceptions-list mapping -- neither should be reported. On the
# freeform side: Group.Key is declared and present live (a mismatch against
# freeform's "absent" default); Group.AbsentKey is declared but never applied
# live, so it matches the absent default and isn't reported; Other.Undeclared
# is present live but never declared, and must never surface via broad scan
# since freeform has no schema to enumerate from.
printf '[General]\nGreeting=Bonjour\nRealKey=ChangedAlias\n' >$HOME/.config/testrc
printf '[Group]\nKey=CustomValue\n\n[Other]\nUndeclared=ShouldNeverAppear\n' >$HOME/.config/somefreeform
printf 'testrc.General.Greeting=Bonjour\nsomefreeform.Group.Key=CustomValue\nsomefreeform.Group.AbsentKey=NeverApplied\n' >$HOME/.config/dot/kde-manifest
set -l manifest_before_diff (cat $HOME/.config/dot/kde-manifest | string collect)

set -l diff_output (dot kde diff)
set -l diff_status $status
set -l manifest_after_diff (cat $HOME/.config/dot/kde-manifest | string collect)

@test "dot kde diff succeeds" $diff_status -eq 0
@test "dot kde diff tags an already-declared mismatch as declared" (string match -q '*declared testrc.General.Greeting = Bonjour (default: Hello)*' -- $diff_output; echo $status) -eq 0
@test "dot kde diff tags a never-declared mismatch as undeclared" (string match -q '*undeclared testrc.General.RealKey = ChangedAlias (default: AliasDefault)*' -- $diff_output; echo $status) -eq 0
@test "dot kde diff does not report a setting matching its default (unset key)" (string match -q '*Some.Key With Spaces*' -- $diff_output; echo $status) -eq 1
@test "dot kde diff does not report a setting matching its default (arg=true mapping)" (string match -q '*BorderSize*' -- $diff_output; echo $status) -eq 1
@test "dot kde diff reports an already-declared freeform mismatch (default is absent)" (string match -q '*declared somefreeform.Group.Key = CustomValue (default: )*' -- $diff_output; echo $status) -eq 0
@test "dot kde diff does not report a declared freeform entry matching its absent default" (string match -q '*AbsentKey*' -- $diff_output; echo $status) -eq 1
@test "dot kde diff never surfaces an undeclared freeform setting via broad scan" (string match -q '*Undeclared*' -- $diff_output; echo $status) -eq 1
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

# --- dot setup folders ---
# The legacy->short-name mapping is fixed in the command itself, not read
# from ~/.config/user-dirs.dirs (a separate, manually tracked dotfile this
# command never reads or writes), so no scenario below needs to seed one.

# xdg-user-dirs-update is faked out via a PATH-prepended bin that logs each
# invocation, exactly mirroring dot install's fake sudo/pacman.
set -l fake_bin_xdg (mktemp -d)
echo '#!/bin/sh
echo "$@" >>"$XDG_UPDATE_LOG"
exit 0' >$fake_bin_xdg/xdg-user-dirs-update
chmod +x $fake_bin_xdg/xdg-user-dirs-update
set -gx PATH $fake_bin_xdg $PATH

# --- a fresh migration: all 8 legacy folders present and empty, including a
#     nested empty Pictures/Screenshots ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Desktop $HOME/Documents $HOME/Downloads $HOME/Music $HOME/Pictures/Screenshots $HOME/Videos $HOME/Templates $HOME/Public
set -gx XDG_UPDATE_LOG (mktemp)

dot setup folders >/dev/null 2>&1
set -l fresh_folders_status $status

@test "dot setup folders succeeds on a fresh scratch HOME" $fresh_folders_status -eq 0
@test "Desktop is renamed to .desktop" -d $HOME/.desktop
@test "Documents is renamed to doc" -d $HOME/doc
@test "Downloads is renamed to dwn" -d $HOME/dwn
@test "Music is renamed to mus" -d $HOME/mus
@test "Pictures is renamed to pic" -d $HOME/pic
@test "Videos is renamed to vid" -d $HOME/vid
@test "Templates and Public both merge into .ignoreme" -d $HOME/.ignoreme
@test "the nested Screenshots folder is renamed to pic/screenshots" -d $HOME/pic/screenshots
@test "the legacy Desktop folder no longer exists" (test -e $HOME/Desktop; and echo yes; or echo no) = no
@test "the legacy Documents folder no longer exists" (test -e $HOME/Documents; and echo yes; or echo no) = no
@test "the legacy Pictures folder no longer exists" (test -e $HOME/Pictures; and echo yes; or echo no) = no
@test "xdg-user-dirs-update is invoked exactly once" (cat $XDG_UPDATE_LOG | count) -eq 1

# --- re-running after a clean migration is a no-op ---
dot setup folders >/dev/null 2>&1
set -l rerun_status $status

@test "re-running dot setup folders succeeds" $rerun_status -eq 0
@test "re-running leaves the short-named folders in place" -d $HOME/pic/screenshots
@test "re-running does not recreate any legacy folder" (test -e $HOME/Pictures; and echo yes; or echo no) = no

# --- the short-name mapping is fixed regardless of what (if anything)
#     ~/.config/user-dirs.dirs declares -- this is the exact real-world bug
#     that motivated dropping the dependency: a stale, never-updated
#     user-dirs.dirs (still pointing XDG_DOCUMENTS_DIR at ~/Documents itself)
#     must not make the target collide with the legacy folder ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/.config
echo 'XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/"
XDG_PUBLICSHARE_DIR="$HOME/"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"' >$HOME/.config/user-dirs.dirs
mkdir -p $HOME/Documents
echo real-content >$HOME/Documents/report.txt
set -gx XDG_UPDATE_LOG (mktemp)

dot setup folders >/dev/null 2>&1

@test "a stale user-dirs.dirs pointing at the legacy folder itself doesn't confuse the migration" (cat $HOME/doc/report.txt) = real-content
@test "the legacy folder is still removed despite the stale user-dirs.dirs" (test -e $HOME/Documents; and echo yes; or echo no) = no
@test "the stale user-dirs.dirs file itself is left byte-for-byte untouched" (string match -q '*XDG_DOCUMENTS_DIR="$HOME/Documents"*' -- (cat $HOME/.config/user-dirs.dirs); echo $status) -eq 0

# --- dot setup folders works even when user-dirs.dirs doesn't exist at all ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Documents
echo real-content >$HOME/Documents/report.txt
set -gx XDG_UPDATE_LOG (mktemp)

set -l no_user_dirs_status
dot setup folders >/dev/null 2>&1
set no_user_dirs_status $status

@test "dot setup folders succeeds with no user-dirs.dirs present at all" $no_user_dirs_status -eq 0
@test "migration still happens with no user-dirs.dirs present at all" (cat $HOME/doc/report.txt) = real-content
@test "no user-dirs.dirs is created as a side effect" (test -e $HOME/.config/user-dirs.dirs; and echo yes; or echo no) = no

# --- bare `dot setup` (no task given) runs folders as part of running everything ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Desktop $HOME/Documents $HOME/Downloads $HOME/Music $HOME/Pictures $HOME/Videos $HOME/Templates $HOME/Public
set -gx XDG_UPDATE_LOG (mktemp)

dot setup >/dev/null 2>&1
set -l bare_setup_status $status

@test "bare dot setup succeeds" $bare_setup_status -eq 0
@test "bare dot setup runs the folders task" -d $HOME/.desktop
@test "bare dot setup also merges Pictures into pic" -d $HOME/pic

# --- a non-empty legacy folder merges unconditionally, no flag needed --
#     an unrelated empty legacy folder migrates in the same run ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Documents $HOME/Desktop
echo real-content >$HOME/Documents/report.txt
set -gx XDG_UPDATE_LOG (mktemp)

set -l nonempty_output (dot setup folders 2>&1)
set -l nonempty_status $status

@test "dot setup folders succeeds when a legacy folder has content" $nonempty_status -eq 0
@test "a non-empty legacy folder's content is migrated by default" (cat $HOME/doc/report.txt) = real-content
@test "the now-empty legacy folder is removed" (test -e $HOME/Documents; and echo yes; or echo no) = no
@test "prints a message about what was moved" (string match -q '*Documents*' -- $nonempty_output; echo $status) -eq 0
@test "an unrelated empty legacy folder still migrates in the same run" (test -e $HOME/Desktop; and echo yes; or echo no) = no

# --- a legacy folder containing only a stray dotfile still migrates by
#     default -- there's no separate empty-vs-non-empty gate to trip ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Downloads
touch $HOME/Downloads/.directory
set -gx XDG_UPDATE_LOG (mktemp)

dot setup folders >/dev/null 2>&1

@test "a legacy folder holding only a stray dotfile is migrated by default" -e $HOME/dwn/.directory
@test "the legacy folder holding only a stray dotfile is removed" (test -e $HOME/Downloads; and echo yes; or echo no) = no

# --- a nested empty Screenshots folder migrates alongside unrelated real
#     content in the same Pictures folder, all in the same default run ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Pictures/Screenshots
echo vacation-photo >$HOME/Pictures/vacation.jpg
set -gx XDG_UPDATE_LOG (mktemp)

dot setup folders >/dev/null 2>&1
set -l pictures_with_content_status $status

@test "dot setup folders succeeds when Pictures has unrelated content" $pictures_with_content_status -eq 0
@test "the unrelated file in Pictures is migrated into pic" (cat $HOME/pic/vacation.jpg) = vacation-photo
@test "the nested Screenshots folder is renamed to pic/screenshots" -d $HOME/pic/screenshots
@test "the now-empty Pictures folder is removed" (test -e $HOME/Pictures; and echo yes; or echo no) = no

# --- a Screenshots folder that itself holds real content migrates by
#     default too, renamed to pic/screenshots, even when the rest of
#     Pictures is empty ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Pictures/Screenshots
echo shot-content >$HOME/Pictures/Screenshots/shot.png
set -gx XDG_UPDATE_LOG (mktemp)

dot setup folders >/dev/null 2>&1

@test "a non-empty Screenshots folder migrates by default, renamed to pic/screenshots" (cat $HOME/pic/screenshots/shot.png) = shot-content
@test "the now-empty Pictures folder is removed after migrating Screenshots" (test -e $HOME/Pictures; and echo yes; or echo no) = no

# --- a filename collision between a legacy folder and its already-populated
#     short-named target is skipped (not overwritten), reported, and leaves
#     the legacy folder in place -- even when another non-colliding file in
#     the same folder is merged successfully ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Documents $HOME/doc
echo legacy-content >$HOME/Documents/report.txt
echo legacy-only >$HOME/Documents/notes.txt
echo target-content >$HOME/doc/report.txt
set -gx XDG_UPDATE_LOG (mktemp)

set -l collision_output (dot setup folders 2>&1)
set -l collision_status $status

@test "dot setup folders still succeeds when a collision occurs" $collision_status -eq 0
@test "the colliding target file is preserved byte-for-byte" (cat $HOME/doc/report.txt) = target-content
@test "the colliding legacy file is left in place, untouched" (cat $HOME/Documents/report.txt) = legacy-content
@test "the collision is reported" (string match -q '*report.txt*' -- $collision_output; echo $status) -eq 0
@test "the legacy Documents folder is left in place due to the collision" -d $HOME/Documents
@test "a non-colliding file in the same folder is still merged" (cat $HOME/doc/notes.txt) = legacy-only
@test "the merged non-colliding file no longer sits in the legacy folder" (test -e $HOME/Documents/notes.txt; and echo yes; or echo no) = no

# --- re-running after a collision was reported: the skipped file isn't
#     lost, and the already-migrated file isn't moved again ---
dot setup folders >/dev/null 2>&1

@test "re-running after a collision still preserves the target file" (cat $HOME/doc/report.txt) = target-content
@test "re-running after a collision still leaves the legacy file in place" (cat $HOME/Documents/report.txt) = legacy-content
@test "re-running after a collision does not resurrect the already-migrated file in the legacy folder" (test -e $HOME/Documents/notes.txt; and echo yes; or echo no) = no

# --- a collision on the nested Screenshots unit is skipped, reported, and
#     leaves Pictures in place, even though Pictures also holds other
#     content unrelated to the collision ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Pictures/Screenshots $HOME/pic/screenshots
echo legacy-shot >$HOME/Pictures/Screenshots/shot.png
echo target-shot >$HOME/pic/screenshots/shot.png
set -gx XDG_UPDATE_LOG (mktemp)

set -l screenshots_collision_output (dot setup folders 2>&1)

@test "a Screenshots collision preserves the existing target screenshot" (cat $HOME/pic/screenshots/shot.png) = target-shot
@test "a Screenshots collision leaves the legacy Screenshots folder in place" (cat $HOME/Pictures/Screenshots/shot.png) = legacy-shot
@test "the Screenshots collision is reported" (string match -q '*Screenshots*' -- $screenshots_collision_output; echo $status) -eq 0
@test "Pictures itself is left in place due to the Screenshots collision" -d $HOME/Pictures

# --- the same Screenshots-collision handling also holds when Pictures has
#     nothing else in it besides the colliding Screenshots folder ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Pictures/Screenshots $HOME/pic/screenshots
echo target-shot >$HOME/pic/screenshots/shot.png
set -gx XDG_UPDATE_LOG (mktemp)

set -l bare_screenshots_collision_output (dot setup folders 2>&1)
set -l bare_screenshots_collision_status $status

@test "a Screenshots-only collision still succeeds" $bare_screenshots_collision_status -eq 0
@test "a Screenshots-only collision preserves the existing target screenshot" (cat $HOME/pic/screenshots/shot.png) = target-shot
@test "a Screenshots-only collision leaves the empty legacy Screenshots folder in place" -d $HOME/Pictures/Screenshots
@test "a Screenshots-only collision leaves Pictures itself in place" -d $HOME/Pictures
@test "the Screenshots-only collision is reported" (string match -q '*Screenshots*' -- $bare_screenshots_collision_output; echo $status) -eq 0

# --- --dry-run reports what would move/skip without touching the
#     filesystem: no mkdir, no mv/rmdir, no xdg-user-dirs-update ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Documents $HOME/Pictures/Screenshots
echo real-content >$HOME/Documents/report.txt
set -gx XDG_UPDATE_LOG (mktemp)

set -l dryrun_output (dot setup folders --dry-run 2>&1)
set -l dryrun_status $status

@test "dot setup folders --dry-run succeeds" $dryrun_status -eq 0
@test "--dry-run reports the entry it would move" (string match -q '*Documents*' -- $dryrun_output; echo $status) -eq 0
@test "--dry-run reports the Screenshots folder it would move" (string match -q '*Screenshots*' -- $dryrun_output; echo $status) -eq 0
@test "--dry-run leaves the legacy Documents folder's content untouched" (cat $HOME/Documents/report.txt) = real-content
@test "--dry-run does not remove the legacy Documents folder" -d $HOME/Documents
@test "--dry-run does not create the short-named target folder" (test -e $HOME/doc; and echo yes; or echo no) = no
@test "--dry-run does not rename the nested Screenshots folder" -d $HOME/Pictures/Screenshots
@test "--dry-run never invokes xdg-user-dirs-update" (test -s $XDG_UPDATE_LOG; and echo yes; or echo no) = no

# --- --dry-run also reports a would-be collision without touching
#     either side, and doesn't move the non-colliding entry either ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Documents $HOME/doc
echo legacy-content >$HOME/Documents/report.txt
echo legacy-only >$HOME/Documents/notes.txt
echo target-content >$HOME/doc/report.txt
set -gx XDG_UPDATE_LOG (mktemp)

set -l dryrun_collision_output (dot setup folders --dry-run 2>&1)

@test "--dry-run reports the would-be collision" (string match -q '*report.txt*' -- $dryrun_collision_output; echo $status) -eq 0
@test "--dry-run leaves the colliding target file untouched" (cat $HOME/doc/report.txt) = target-content
@test "--dry-run leaves the colliding legacy file untouched" (cat $HOME/Documents/report.txt) = legacy-content
@test "--dry-run does not move the non-colliding file either" -e $HOME/Documents/notes.txt

# --- a legacy folder with nothing to move produces no --dry-run output ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Desktop
set -gx XDG_UPDATE_LOG (mktemp)

set -l dryrun_empty_output (dot setup folders --dry-run 2>&1)

@test "--dry-run is silent for a legacy folder with nothing to move" -z "$dryrun_empty_output"
@test "--dry-run leaves an empty legacy folder in place" -d $HOME/Desktop

# --- the removed --yes flag now fails fast as an unknown option ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
set -gx XDG_UPDATE_LOG (mktemp)

dot setup folders --yes >/dev/null 2>&1
set -l old_yes_status $status

@test "dot setup folders --yes now fails as an unknown option" $old_yes_status -ne 0

# --- help prints usage and makes no filesystem changes ---
set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands/setup
cp $commands_dir/setup/setup.fish $HOME/.config/dot/commands/setup/setup.fish
cp $commands_dir/setup/folders.fish $HOME/.config/dot/commands/setup/folders.fish
mkdir -p $HOME/Documents $HOME/Desktop
set -gx XDG_UPDATE_LOG (mktemp)

set -l setup_help_output (dot setup help)
set -l setup_help_status $status
set -l folders_help_output (dot setup folders help)
set -l folders_help_status $status
set -l xdg_called_for_help (test -s $XDG_UPDATE_LOG; and echo yes; or echo no)

@test "dot setup help succeeds" $setup_help_status -eq 0
@test "dot setup help mentions folders" (string match -q '*folders*' -- $setup_help_output; echo $status) -eq 0
@test "dot setup folders help succeeds" $folders_help_status -eq 0
@test "dot setup folders help mentions the short-name convention" (string match -q '*.desktop*' -- $folders_help_output; echo $status) -eq 0
@test "dot setup folders help documents --dry-run" (string match -q '*--dry-run*' -- $folders_help_output; echo $status) -eq 0
@test "neither help invocation ever calls xdg-user-dirs-update" $xdg_called_for_help = no
@test "dot setup help leaves the legacy Documents folder untouched" -d $HOME/Documents
@test "dot setup folders help leaves the legacy Desktop folder untouched" -d $HOME/Desktop
@test "help does not create any short-named target folder" (test -e $HOME/doc; and echo yes; or echo no) = no

# --- dot help discovers dot setup ---
set -l help_with_setup (dot help)
@test "dot help lists the setup subcommand" (string match -q '*setup*' -- $help_with_setup; echo $status) -eq 0

# --- dot vpn ---
# nmcli is faked out via a PATH-prepended bin that logs each invocation and
# fails only when $NMCLI_FAIL is set, mirroring dot install's fake pacman.
set -l fake_bin_vpn (mktemp -d)
echo '#!/bin/sh
echo "$@" >>"$NMCLI_LOG"
if [ -n "$NMCLI_FAIL" ]; then
    exit 1
fi
exit 0' >$fake_bin_vpn/nmcli
chmod +x $fake_bin_vpn/nmcli
set -gx PATH $fake_bin_vpn $PATH

set -gx HOME (mktemp -d)
dot init --url $remote >/dev/null 2>&1
mkdir -p $HOME/.config/dot/commands
cp $commands_dir/vpn.fish $HOME/.config/dot/commands/vpn.fish
set -gx NMCLI_LOG (mktemp)

dot vpn up >/dev/null 2>&1
set -l vpn_up_status $status
set -l vpn_up_called (string match -q '*connection up UDM-PRO-Laptop*' -- (cat $NMCLI_LOG); and echo yes; or echo no)

@test "dot vpn up succeeds" $vpn_up_status -eq 0
@test "dot vpn up calls nmcli connection up UDM-PRO-Laptop" $vpn_up_called = yes

set -gx NMCLI_LOG (mktemp)
dot vpn down >/dev/null 2>&1
set -l vpn_down_status $status
set -l vpn_down_called (string match -q '*connection down UDM-PRO-Laptop*' -- (cat $NMCLI_LOG); and echo yes; or echo no)

@test "dot vpn down succeeds" $vpn_down_status -eq 0
@test "dot vpn down calls nmcli connection down UDM-PRO-Laptop" $vpn_down_called = yes

# --- dot vpn help touches nmcli not at all ---
set -gx NMCLI_LOG (mktemp)
set -l vpn_help_output (dot vpn help)
set -l vpn_help_status $status
set -l nmcli_called_for_vpn_help (test -s $NMCLI_LOG; and echo yes; or echo no)

@test "dot vpn help succeeds" $vpn_help_status -eq 0
@test "dot vpn help mentions up" (string match -q '*up*' -- $vpn_help_output; echo $status) -eq 0
@test "dot vpn help mentions down" (string match -q '*down*' -- $vpn_help_output; echo $status) -eq 0
@test "dot vpn help never invokes nmcli" $nmcli_called_for_vpn_help = no

# --- an unrecognized subcommand prints usage and fails, without calling nmcli ---
set -gx NMCLI_LOG (mktemp)
dot vpn bogus >/dev/null 2>&1
set -l vpn_bogus_status $status
set -l nmcli_called_for_bogus (test -s $NMCLI_LOG; and echo yes; or echo no)

@test "dot vpn with an unrecognized subcommand fails" $vpn_bogus_status -ne 0
@test "an unrecognized dot vpn subcommand never invokes nmcli" $nmcli_called_for_bogus = no

# --- bare `dot vpn` (no subcommand) also prints usage and fails ---
set -gx NMCLI_LOG (mktemp)
dot vpn >/dev/null 2>&1
set -l vpn_bare_status $status

@test "bare dot vpn fails" $vpn_bare_status -ne 0

# --- a failing nmcli call propagates its exit status ---
set -gx NMCLI_FAIL 1
dot vpn up >/dev/null 2>&1
set -l vpn_up_fail_status $status
set -e NMCLI_FAIL

@test "dot vpn up fails when nmcli fails" $vpn_up_fail_status -ne 0

# --- dot help discovers dot vpn ---
set -l help_with_vpn (dot help)
@test "dot help lists the vpn subcommand" (string match -q '*vpn*' -- $help_with_vpn; echo $status) -eq 0
