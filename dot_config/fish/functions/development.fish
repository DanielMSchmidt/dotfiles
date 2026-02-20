function tmpdir -d "Creates a temporary directory and switches into it"
    cd (mktemp -d)
end

function jira -d "Opens jira for this branch"
    open "https://hashicorp.atlassian.net/browse/$(git branch --show-current)"
end

function jiramd -d "Puts markdown link to jira in clipboard"
    echo "[$(git branch --show-current)](https://hashicorp.atlassian.net/browse/$(git branch --show-current))" | pbcopy
end

function goTestAll -d "Runs all tests in the current directory without caching"
    CHECKPOINT_DISABLE= go test -v -count=1 ./... | go-again remember
end

function goTestFails -d "Runs all tests and finds fails"
    goTestAll | grep "FAIL"
end

function goTestSingle -d "Runs tests in a single file without caching" 
    if test (count $argv) -ne 2
        echo "Usage: goTestSingle <modulePath> <testCase>"
        return 1
    end
    echo "goTestSingle $argv[1] $argv[2]"
    echo "Running gow -c test -v -count=1 $argv[1] -run $argv[2]\$"; CHECKPOINT_DISABLE= gow -c test -v -count=1 $argv[1] -run $argv[2]\$
end

function triggerwatch -d "Watches for a trigger and runs the given command when triggered"
    set -l triggerfile /tmp/fish_triggerwatch_trigger
    set -l cmd $argv

    echo "Watching for trigger. Run 'triggerfire' in another shell to trigger."
    while true
        if test -f $triggerfile
            rm $triggerfile
            echo "Trigger fired, executing command: $cmd"
            eval $cmd
        end
        sleep 1
    end
end

function triggerfire -d "Fires the trigger for triggerwatch"
    set -l triggerfile /tmp/fish_triggerwatch_trigger
    touch $triggerfile
end

function triggerfireblock -d "Fires the trigger for triggerwatch and waits until it's processed"
    set -l triggerfile /tmp/fish_triggerwatch_trigger
    touch $triggerfile
    echo "Trigger fired, waiting for processing..."
    while test -f $triggerfile
        sleep 0.1
    end
    echo "Trigger processed."
end

# Print dot graph to terminal
function dotgraph
    pbpaste | dot -T png -Gbgcolor=transparent | viu -
end

function nosleep -d "Prevents the computer from sleeping, even with lid closed (Ctrl+C to stop)"
    echo "Preventing sleep (including with lid closed)... Press Ctrl+C to stop."
    echo "Note: -s flag requires AC power to prevent sleep with lid closed"
    caffeinate -i -s -u -d
end

function prchain -d "Lists all connected PRs in a chain (PRs stacked on each other)"
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    # Get current branch
    set -l current_branch (git branch --show-current)
    if test -z "$current_branch"
        echo "Error: Not on a branch (detached HEAD?)"
        return 1
    end

    # Check if gh CLI is available
    if not command -q gh
        echo "Error: GitHub CLI (gh) is not installed"
        return 1
    end

    # Get PR for current branch
    set -l current_pr_json (gh pr view --json number,title,url,baseRefName,headRefName 2>/dev/null)
    if test $status -ne 0
        echo "Error: No PR found for branch '$current_branch'"
        return 1
    end

    # Parse current PR info
    set -l current_pr_number (echo $current_pr_json | jq -r '.number')
    set -l current_head (echo $current_pr_json | jq -r '.headRefName')
    set -l current_base (echo $current_pr_json | jq -r '.baseRefName')

    # Initialize arrays to store the chain
    set -l pr_numbers
    set -l pr_titles
    set -l pr_urls
    set -l pr_heads
    set -l pr_bases

    # Get all open PRs in the repo
    set -l all_prs (gh pr list --json number,title,url,baseRefName,headRefName --limit 200)

    # Walk up the chain: find PRs where the head branch is the base of the current/next PR
    # We only include a PR if its head branch is being used as a base by another PR in our chain
    set -l walk_branch $current_base
    set -l upstream_numbers
    set -l upstream_titles
    set -l upstream_urls
    set -l upstream_heads
    set -l upstream_bases

    while true
        # Find a PR whose head branch matches walk_branch AND whose head is used as a base by another PR
        # This ensures we only get PRs that are actually stacked
        set -l found_pr (echo $all_prs | jq -r --arg branch "$walk_branch" '.[] | select(.headRefName == $branch) | "\(.number)\t\(.title)\t\(.url)\t\(.headRefName)\t\(.baseRefName)"')
        if test -z "$found_pr"
            break
        end
        
        set -l pr_num (echo $found_pr | cut -f1)
        set -l pr_title (echo $found_pr | cut -f2)
        set -l pr_url (echo $found_pr | cut -f3)
        set -l pr_head (echo $found_pr | cut -f4)
        set -l pr_base (echo $found_pr | cut -f5)

        # Check if this PR's head is actually used as a base by another PR (i.e., it's part of a stack)
        # The walk_branch is the base of the PR we came from, so if there's a PR with head=walk_branch,
        # it means that PR is being stacked upon
        set -l is_stacked_upon (echo $all_prs | jq -r --arg branch "$pr_head" '[.[] | select(.baseRefName == $branch)] | length')
        if test "$is_stacked_upon" = "0"
            # This PR's head is not used as a base by any other PR, so it's not part of a stack
            break
        end

        # Prepend to upstream arrays (we're walking backwards)
        set upstream_numbers $pr_num $upstream_numbers
        set upstream_titles $pr_title $upstream_titles
        set upstream_urls $pr_url $upstream_urls
        set upstream_heads $pr_head $upstream_heads
        set upstream_bases $pr_base $upstream_bases

        set walk_branch $pr_base
    end

    # Now walk down from current PR's head (find PRs based on current branch)
    set walk_branch $current_head
    set -l downstream_numbers
    set -l downstream_titles
    set -l downstream_urls
    set -l downstream_heads
    set -l downstream_bases

    # Skip the current PR itself, start from PRs based on current head
    while true
        set -l found_pr (echo $all_prs | jq -r --arg branch "$walk_branch" '.[] | select(.baseRefName == $branch) | "\(.number)\t\(.title)\t\(.url)\t\(.headRefName)\t\(.baseRefName)"')
        if test -z "$found_pr"
            break
        end
        set -l pr_num (echo $found_pr | cut -f1)
        set -l pr_title (echo $found_pr | cut -f2)
        set -l pr_url (echo $found_pr | cut -f3)
        set -l pr_head (echo $found_pr | cut -f4)
        set -l pr_base (echo $found_pr | cut -f5)

        set -a downstream_numbers $pr_num
        set -a downstream_titles $pr_title
        set -a downstream_urls $pr_url
        set -a downstream_heads $pr_head
        set -a downstream_bases $pr_base

        set walk_branch $pr_head
    end

    # Combine all: upstream + current + downstream
    set pr_numbers $upstream_numbers $current_pr_number $downstream_numbers
    set pr_titles $upstream_titles (echo $current_pr_json | jq -r '.title') $downstream_titles
    set pr_urls $upstream_urls (echo $current_pr_json | jq -r '.url') $downstream_urls

    # Output as markdown list
    echo "## PR Chain"
    echo ""
    for i in (seq (count $pr_numbers))
        # Check if this is the current PR
        if test "$pr_numbers[$i]" = "$current_pr_number"
            echo "- **[#$pr_numbers[$i]: $pr_titles[$i]]($pr_urls[$i])** ← you are here"
        else
            echo "- [#$pr_numbers[$i]: $pr_titles[$i]]($pr_urls[$i])"
        end
    end
end

function prRebasePushAll -d "Pull --rebase and force-push all open PRs; skip PRs where rebase fails and report them"
    # Ensure we're in a clean git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    if test -n (git status --porcelain)
        echo "Error: Working tree is not clean. Please commit or stash changes before running this."
        return 1
    end

    # Ensure gh CLI is available
    if not command -q gh
        echo "Error: GitHub CLI (gh) is not installed"
        return 1
    end

    # Remember original branch to return to
    set -l original_branch (git branch --show-current)

    # Prepare list of open PRs
    set -l all_prs_json (gh pr list --limit 200 --json number,headRefName 2>/dev/null)
    if test $status -ne 0
        echo "Error: Failed to list PRs with gh"
        return 1
    end

    # Build an array of "number<TAB>branch"
    set -l pr_lines (echo $all_prs_json | jq -r '.[] | "\(.number)\t\(.headRefName)"')

    if test -z "$pr_lines"
        echo "No open PRs found."
        return 0
    end

    set -l failed_prs
    set -l failed_reasons

    for line in $pr_lines
        set -l pr_num (echo $line | cut -f1)
        set -l pr_branch (echo $line | cut -f2)

        if test -z "$pr_branch" -o -z "$pr_num"
            echo "Skipping malformed PR entry: $line"
            continue
        end

        echo "----------------------------------------"
        echo "Processing PR #$pr_num (branch: $pr_branch)"

        # Checkout the PR locally (gh will set up remotes if needed)
        gh pr checkout $pr_num >/dev/null 2>&1
        if test $status -ne 0
            echo "  Error: gh pr checkout failed for PR #$pr_num"
            set -a failed_prs $pr_num
            set -a failed_reasons "checkout-failed"
            continue
        end

        # Ensure we are on the intended branch
        set -l current_branch (git branch --show-current)
        if test "$current_branch" != "$pr_branch"
            # Some repos/gh versions may name the checked out branch differently; still proceed but warn
            echo "  Warning: checked out branch is '$current_branch' (expected '$pr_branch')"
        end

        # Attempt to pull --rebase with autostash to minimize manual intervention
        echo "  Pulling --rebase..."
        git pull --rebase --autostash >/dev/null 2>&1
        if test $status -ne 0
            echo "  Rebase failed for PR #$pr_num. Aborting rebase and skipping push."
            # Try to abort any in-progress rebase
            git rebase --abort >/dev/null 2>&1
            set -a failed_prs $pr_num
            set -a failed_reasons "rebase-failed"
            continue
        end

        # Determine upstream to push to
        set -l upstream
        git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1
        if test $status -eq 0
            set upstream (git rev-parse --abbrev-ref --symbolic-full-name @{u})
        else
            # Fall back to origin/<branch>
            set upstream "origin/$current_branch"
            echo "  No upstream configured; defaulting push target to $upstream"
        end

        # Split upstream into remote and branch
        set -l remote (echo $upstream | cut -d/ -f1)
        set -l remote_branch (echo $upstream | cut -d/ -f2-)

        if test -z "$remote" -o -z "$remote_branch"
            echo "  Error: Could not determine remote/branch for push target. Skipping."
            set -a failed_prs $pr_num
            set -a failed_reasons "no-upstream"
            continue
        end

        # Force-push with lease to avoid clobbering unexpected remote changes
        echo "  Force-pushing to $remote/$remote_branch..."
        git push --force-with-lease $remote HEAD:$remote_branch >/dev/null 2>&1
        if test $status -ne 0
            echo "  Error: Force-push failed for PR #$pr_num"
            set -a failed_prs $pr_num
            set -a failed_reasons "push-failed"
            continue
        end

        echo "  Successfully rebased and force-pushed PR #$pr_num"
    end

    # Return to original branch if present
    if test -n "$original_branch"
        echo "Returning to original branch '$original_branch'..."
        git checkout $original_branch >/dev/null 2>&1
    end

    echo "----------------------------------------"
    if test (count $failed_prs) -gt 0
        echo "The following PRs were skipped due to errors:"
        for i in (seq (count $failed_prs))
            echo "- PR #$failed_prs[$i]: $failed_reasons[$i]"
        end
        return 1
    else
        echo "All PRs processed successfully."
        return 0
    end
end

function todos -d "Find TODOs and FIXMEs added in the PR/branch (only newly added lines)"
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    # Determine the base branch to compare against
    set -l base_branch

    # Check if we're on a PR by trying to get PR info
    if command -q gh
        set -l pr_base (gh pr view --json baseRefName -q '.baseRefName' 2>/dev/null)
        if test $status -eq 0 -a -n "$pr_base"
            set base_branch $pr_base
            echo "📌 On a PR, comparing against base branch: $base_branch"
        end
    end

    # Fall back to main if not on a PR
    if test -z "$base_branch"
        # Check if main exists, otherwise try master
        if git rev-parse --verify main >/dev/null 2>&1
            set base_branch main
        else if git rev-parse --verify master >/dev/null 2>&1
            set base_branch master
        else
            echo "Error: Could not find main or master branch"
            return 1
        end
        echo "📌 Not on a PR, comparing against: $base_branch"
    end

    # Fetch the base branch to ensure we have latest
    git fetch origin $base_branch 2>/dev/null

    # Get the diff and find added lines containing TODO/FIXME
    # Using git diff with line number info to track where TODOs were added
    set -l diff_base origin/$base_branch
    if not git rev-parse --verify $diff_base >/dev/null 2>&1
        set diff_base $base_branch
    end

    echo ""
    echo "🔍 Searching for TODOs and FIXMEs added in this branch..."
    echo ""

    set -l found_todos 0
    set -l current_file ""
    set -l current_line_num 0

    # Parse the unified diff to find added TODO lines with their actual line numbers
    # Using -U0 to get minimal context, then parsing the @@ headers for line numbers
    set -l diff_output (git diff -U0 $diff_base -- 2>/dev/null)

    for line in $diff_output
        # Check for file header
        if string match -q "diff --git*" -- $line
            continue
        else if string match -q "+++ b/*" -- $line
            # Extract filename from +++ b/path/to/file
            set current_file (string replace "+++ b/" "" -- $line)
            continue
        else if string match -qr '@@.*\+([0-9]+)' -- $line
            # Parse hunk header to get the starting line number in the new file
            # Format: @@ -old_start,old_count +new_start,new_count @@
            set -l hunk_info (string match -r '@@ -[0-9,]+ \+([0-9]+)' -- $line)
            if test -n "$hunk_info[2]"
                set current_line_num $hunk_info[2]
            end
            continue
        else if string match -q "+*" -- $line
            # This is an added line - check if it contains TODO/FIXME
            # Skip the +++ header lines
            if string match -q "++*" -- $line
                continue
            end

            set -l line_content (string sub -s 2 -- $line)

            if string match -qri "(TODO|FIXME)" -- $line_content
                set found_todos (math $found_todos + 1)

                # Check if file exists for context
                if test -f $current_file
                    # Calculate context range (3 lines before and after)
                    set -l start_line (math "max(1, $current_line_num - 3)")
                    set -l end_line (math "$current_line_num + 3")

                    # Get total lines in file to avoid going past end
                    set -l total_lines (wc -l < $current_file | tr -d ' ')
                    if test $end_line -gt $total_lines
                        set end_line $total_lines
                    end

                    # Print header with file path and line number
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "📄 $current_file#L$current_line_num"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

                    # Print context with line numbers, highlighting the TODO line
                    set -l ctx_line $start_line
                    while test $ctx_line -le $end_line
                        set -l ctx_content (sed -n "$ctx_line"p $current_file)
                        if test $ctx_line -eq $current_line_num
                            # Highlight the TODO line
                            printf "\033[1;33m%4d │ %s\033[0m\n" $ctx_line "$ctx_content"
                        else
                            printf "%4d │ %s\n" $ctx_line "$ctx_content"
                        end
                        set ctx_line (math $ctx_line + 1)
                    end
                    echo ""
                else
                    # File doesn't exist, just show the line from diff
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "📄 $current_file#L$current_line_num"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    printf "\033[1;33m%4d │ %s\033[0m\n" $current_line_num "$line_content"
                    echo ""
                end
            end

            # Increment line number for each added line
            set current_line_num (math $current_line_num + 1)
        else if not string match -q -- "-*" $line
            # Context line (no + or -) - increment line number
            # But we're using -U0 so there shouldn't be context lines
            continue
        end
        # Removed lines (starting with -) don't affect new file line numbers
    end

    if test $found_todos -eq 0
        echo "✅ No TODOs or FIXMEs added in this branch."
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 Found $found_todos TODO/FIXME(s) added in this branch."
    end
end


function zedl -d "My local zed fork" 
    set -l zed_bin /Users/dschmidt/fun/zed/target/release/zed
    if not test -x $zed_bin
        echo "Error: zed binary not found or not executable at $zed_bin"
        echo "Run 'cargo build --release' in your zed fork (/Users/dschmidt/fun/zed) to build it first."
        return 1
    end
    
    # Use provided path argument (or arguments) if given
    set -l zed_args
    if test (count $argv) -gt 0
        set -a zed_args $argv
    end
    
    if test (count $zed_args) -gt 0
        echo "Starting zed in background with args: $zed_args"
        nohup $zed_bin $zed_args >/dev/null 2>&1 &
    else
        echo "Starting zed in background"
        nohup $zed_bin >/dev/null 2>&1 &
    end
end