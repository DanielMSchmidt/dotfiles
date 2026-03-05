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

    for entry in CLAUDE.md .claude .claude/worktrees/ docs/plans/
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
    for entry in CLAUDE.md .claude .claude/worktrees/ docs/plans/
        if test -f $exclude_file
            sed -i '' "\|^$entry\$|d" $exclude_file
        end
    end
end
