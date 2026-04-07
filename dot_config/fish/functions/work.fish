function work -d "Git worktree manager with auto-cd (wraps work CLI)"
    set -l tmpfile (mktemp)
    command work $argv 2>&1 | tee $tmpfile
    set -l path (string match -r 'Ready: (.+)' < $tmpfile)[2]
    rm -f $tmpfile
    if test -n "$path"
        cd $path

        # Auto-switch terraform build path for terraform worktrees
        set -l tf_wt_base "$HOME/.worktrees/terraform"
        if string match -q "$tf_wt_base/*" "$path"
            set -l wt_name (basename "$path")
            tfuse $wt_name
        else if string match -q "$HOME/work/hashicorp/terraform" "$path"
            tfuse main
        end
    end
end
