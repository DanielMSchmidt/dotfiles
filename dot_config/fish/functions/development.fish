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
    CHECKPOINT_DISABLE= go test -v -count=1 ./...
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

    # Function to find PR by head branch (walking up the chain)
    # Start by walking up from current PR's base
    set -l walk_branch $current_base
    set -l upstream_numbers
    set -l upstream_titles
    set -l upstream_urls
    set -l upstream_heads
    set -l upstream_bases

    while true
        set -l found_pr (echo $all_prs | jq -r --arg branch "$walk_branch" '.[] | select(.headRefName == $branch) | "\(.number)\t\(.title)\t\(.url)\t\(.headRefName)\t\(.baseRefName)"')
        if test -z "$found_pr"
            break
        end
        set -l pr_num (echo $found_pr | cut -f1)
        set -l pr_title (echo $found_pr | cut -f2)
        set -l pr_url (echo $found_pr | cut -f3)
        set -l pr_head (echo $found_pr | cut -f4)
        set -l pr_base (echo $found_pr | cut -f5)

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
