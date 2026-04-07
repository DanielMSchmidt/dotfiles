function tfuse -d "Switch terraform build to a worktree or main (per-shell)"
    set -l main_path $HOME/work/hashicorp/terraform
    set -l worktree_base $HOME/.worktrees/terraform

    if test (count $argv) -eq 0
        # Interactive mode: pick from worktrees + main via fzf
        set -l current (basename "$TERRAFORM_PATH")
        if test "$TERRAFORM_PATH" = "$main_path"
            set current main
        end

        set -l choices
        # Main is always first
        if test "$current" = "main"
            set -a choices "main *"
        else
            set -a choices "main"
        end

        # Add worktrees
        if test -d "$worktree_base"
            for dir in $worktree_base/*/
                set -l name (basename $dir)
                if test "$name" = "$current"
                    set -a choices "$name *"
                else
                    set -a choices "$name"
                end
            end
        end

        if test (count $choices) -eq 1
            echo "No worktrees found. Use 'work new <branch>' to create one."
            return 0
        end

        set -l pick (printf '%s\n' $choices | fzf --prompt="tfuse> " --header="Current: $current")
        if test -z "$pick"
            return 0
        end
        # Strip the " *" marker
        set pick (string replace ' *' '' $pick)
        tfuse $pick
        return $status
    end

    set -l target $argv[1]

    if test "$target" = "main"
        set -gx TERRAFORM_PATH $main_path
    else
        set -l wt_path "$worktree_base/$target"
        if not test -d "$wt_path"
            echo "Worktree '$target' not found at $wt_path"
            return 1
        end
        set -gx TERRAFORM_PATH $wt_path
    end

    set -gx TFSTACKS_TERRAFORM_BINARY $TERRAFORM_PATH/bin/terraform
    echo "terraform → $TERRAFORM_PATH"

    if not test -x "$TERRAFORM_PATH/bin/terraform"
        echo "(no binary yet — run tfb to build)"
    end
end
