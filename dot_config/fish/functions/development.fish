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
    go test -v -count=1 ./...
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
    echo "Running gow -c test -v -count=1 $argv[1] -run $argv[2]\$"; gow -c test -v -count=1 $argv[1] -run $argv[2]\$
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
