function claudetf -d "Start Claude Code session for terraform/terraform-private with project config"
    # Verify we're in a git repo
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    set -l config_dir ~/.config/claude/terraform
    set -l git_dir (git rev-parse --git-dir)

    # Verify config exists
    if not test -f $config_dir/CLAUDE.md
        echo "Error: $config_dir/CLAUDE.md not found. Run 'chezmoi apply' first."
        return 1
    end

    # Symlink CLAUDE.md
    if test -L CLAUDE.md
        ln -sf $config_dir/CLAUDE.md CLAUDE.md
    else if test -f CLAUDE.md
        echo "Error: CLAUDE.md already exists and is not a symlink"
        return 1
    else
        ln -s $config_dir/CLAUDE.md CLAUDE.md
    end

    # Symlink .claude/
    if test -L .claude
        ln -sf $config_dir/.claude .claude
    else if test -d .claude
        echo "Error: .claude/ already exists and is not a symlink"
        return 1
    else
        ln -s $config_dir/.claude .claude
    end

    # Add to git exclude (not .gitignore) if not already there
    set -l exclude_file $git_dir/info/exclude
    mkdir -p $git_dir/info

    for entry in CLAUDE.md .claude
        if not grep -qxF $entry $exclude_file 2>/dev/null
            echo $entry >>$exclude_file
        end
    end

    # Start claude with any extra args passed through
    claude $argv

    # Cleanup: remove symlinks
    rm -f CLAUDE.md
    test -L .claude; and rm -f .claude

    # Cleanup: remove entries from git exclude
    for entry in CLAUDE.md .claude
        if test -f $exclude_file
            sed -i '' "\|^$entry\$|d" $exclude_file
        end
    end
end

function claudetfwt -d "Start Claude Code session in a git worktree for terraform"
    # Verify we're in a git repo (and not already in a worktree's subdirectory without a main repo)
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    set -l toplevel (git rev-parse --show-toplevel)
    set -l wt_base "$toplevel/.worktrees"

    # Check for existing worktrees (excluding the main one)
    set -l existing_wts
    for line in (git worktree list --porcelain | grep '^worktree ')
        set -l wt_path (string replace 'worktree ' '' -- $line)
        if test "$wt_path" != "$toplevel"
            set -a existing_wts $wt_path
        end
    end

    set -l target_wt

    # Build fzf list: existing worktrees + create new option
    set -l fzf_items
    for wt in $existing_wts
        set -l wt_name (basename $wt)
        set -l wt_branch (git -C $wt branch --show-current 2>/dev/null; or echo "detached")
        set -a fzf_items "$wt_name ($wt_branch)"
    end
    set -a fzf_items "+ Create new worktree"

    set -l selection (printf '%s\n' $fzf_items | fzf --height=~20 --prompt="Worktree: " --header="Select a worktree")
    if test -z "$selection"
        echo "Cancelled"
        return 1
    end

    if test "$selection" != "+ Create new worktree"
        # Match selection back to worktree path
        for i in (seq (count $existing_wts))
            set -l wt_name (basename $existing_wts[$i])
            set -l wt_branch (git -C $existing_wts[$i] branch --show-current 2>/dev/null; or echo "detached")
            if test "$selection" = "$wt_name ($wt_branch)"
                set target_wt $existing_wts[$i]
                break
            end
        end
    end

    if test -z "$target_wt"
        read -P "Worktree name: " wt_name
        if test -z "$wt_name"
            echo "Error: Name cannot be empty"
            return 1
        end

        # Slugify: lowercase, replace non-alphanumeric with hyphens, collapse, trim
        set -l slug (string lower -- $wt_name | string replace -ra '[^a-z0-9]+' '-' | string trim -c '-')
        if test -z "$slug"
            echo "Error: Name produced empty slug"
            return 1
        end

        set target_wt "$wt_base/$slug"
        mkdir -p $wt_base

        if test -d "$target_wt"
            echo "Worktree directory already exists: $target_wt"
            return 1
        end

        echo "Creating worktree at $target_wt (branch: $slug)..."
        git worktree add "$target_wt" -b "$slug"
        if test $status -ne 0
            echo "Error: Failed to create worktree"
            return 1
        end
    end

    echo "Entering worktree: $target_wt"
    cd "$target_wt"
    claudetf $argv
end
