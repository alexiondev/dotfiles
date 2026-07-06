function _dot_setup_folders_usage
    echo "usage: dot setup folders [--dry-run]

Brings the 8 standard XDG user directories under the project's fixed
short-name convention (Desktop -> .desktop, Documents -> doc, Downloads ->
dwn, Music -> mus, Pictures -> pic, Videos -> vid, Templates/Public ->
.ignoreme). This mapping is fixed and does not depend on
~/.config/user-dirs.dirs, which is a separate, manually tracked dotfile
this command never reads or writes.

Content left behind in a legacy full-named folder (e.g. ~/Documents) by a
fresh XDG-defaults install -- empty or not -- is merged into its short-named
replacement. A nested Pictures/Screenshots folder is renamed to
pic/screenshots as part of the same pass.

An entry that collides by name with something already in the short-named
target is never overwritten: it's skipped, reported, and its legacy folder is
left in place (not removed) even when everything else in it migrated.

  --dry-run   report what would move and what would be skipped as a
              collision, without changing anything on disk

Runs xdg-user-dirs-update once afterwards to notify running apps/portals
(skipped under --dry-run)."
end

function _dot_setup_folders
    if test "$argv[1]" = help
        _dot_setup_folders_usage
        return 0
    end

    argparse 'dry-run' -- $argv
    or return 1

    # Fixed legacy-name -> short-name mapping. Deliberately hardcoded rather
    # than read from ~/.config/user-dirs.dirs: that file is a separate,
    # manually tracked dotfile whose XDG_*_DIR values can drift or go stale
    # (or never get edited to the short names at all), and this command's
    # own migration logic must not depend on it being correct.
    set -l legacy_names Desktop Documents Downloads Music Pictures Videos Templates Public
    set -l target_names .desktop doc dwn mus pic vid .ignoreme .ignoreme

    for i in (seq (count $legacy_names))
        set -l legacy_name $legacy_names[$i]
        set -l target_rel $target_names[$i]
        set -l target_path $HOME/$target_rel
        set -l legacy_path $HOME/$legacy_name

        if not set -q _flag_dry_run
            mkdir -p $target_path
        end

        if not test -d $legacy_path
            continue
        end

        # Screenshots is always moved as one atomic unit (renamed to
        # lowercase screenshots), so its individual files must never appear
        # as separate move/report entries.
        set -l screenshots_path $legacy_path/Screenshots
        set -l top_level_entries (find $legacy_path -mindepth 1 -maxdepth 1 -not -name Screenshots)

        # No-clobber: an entry whose name already exists in the target is
        # never moved over. It's collected here and reported below; its
        # legacy folder is left in place (not removed) if any collision
        # occurred, even though everything else in it migrated successfully.
        set -l collisions
        set -l movable_entries
        set -l screenshots_movable 0

        if test -d $screenshots_path
            if test -e $target_path/screenshots
                set -a collisions $screenshots_path
            else
                set screenshots_movable 1
            end
        end

        for entry in $top_level_entries
            if test -e $target_path/(path basename $entry)
                set -a collisions $entry
            else
                set -a movable_entries $entry
            end
        end

        set -l movable_count (count $movable_entries)
        set -l entry_word entries
        test $movable_count -eq 1
        and set entry_word entry

        if set -q _flag_dry_run
            if test $screenshots_movable -eq 1
                echo "dot setup folders: would move $screenshots_path to $target_path/screenshots"
            end
            if test $movable_count -gt 0
                echo "dot setup folders: would move $movable_count $entry_word from ~/$legacy_name to ~/$target_rel"
            end
            if test (count $collisions) -gt 0
                echo "dot setup folders: ~/$legacy_name has entries already present in ~/$target_rel, would skip (not overwritten):"
                for c in $collisions
                    echo "  $c"
                end
                echo "dot setup folders: ~/$legacy_name would remain in place due to the collision(s) above"
            end
            continue
        end

        if test $screenshots_movable -eq 1
            mv -n $screenshots_path $target_path/screenshots
            echo "dot setup folders: moved $screenshots_path to $target_path/screenshots"
        end

        if test $movable_count -gt 0
            mv -n $movable_entries $target_path/
            echo "dot setup folders: moved $movable_count $entry_word from ~/$legacy_name to ~/$target_rel"
        end

        if test (count $collisions) -gt 0
            echo "dot setup folders: ~/$legacy_name has entries already present in ~/$target_rel, skipping (not overwritten):"
            for c in $collisions
                echo "  $c"
            end
            echo "dot setup folders: leaving ~/$legacy_name in place due to the collision(s) above"
        else
            rmdir $legacy_path
        end
    end

    if not set -q _flag_dry_run
        xdg-user-dirs-update
    end
end
