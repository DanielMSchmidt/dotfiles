function local-llm -d "Pause, resume or inspect the local Ollama server (off|on|status)"
    # The server runs as a LaunchAgent with RunAtLoad + KeepAlive, so killing
    # the process is not enough: launchd restarts it at once, and again at the
    # next login. `bootout` stops it and `disable` keeps it stopped across
    # reboots until `on` re-enables it. Note that a `chezmoi apply` which re-runs
    # run_after_onchange_setup-ollama.sh (`launchctl load -w`) also re-enables it.
    set -l label com.danielschmidt.ollama
    set -l plist ~/Library/LaunchAgents/$label.plist
    set -l domain gui/(id -u)

    switch "$argv[1]"
        case off pause stop
            launchctl disable $domain/$label
            if launchctl print $domain/$label >/dev/null 2>&1
                launchctl bootout $domain/$label 2>/dev/null
            end
            echo "local LLM paused (stays off across reboots; resume with: local-llm on)"
        case on resume start
            if not test -f $plist
                echo "Error: $plist is missing — run chezmoi apply first."
                return 1
            end
            launchctl enable $domain/$label
            if not launchctl print $domain/$label >/dev/null 2>&1
                launchctl bootstrap $domain $plist; or return 1
            end
            # Wait for the server so a following `qc`/`ai` does not race it.
            for _ in (seq 1 40)
                ollama ls >/dev/null 2>&1; and break
                sleep 0.25
            end
            echo "local LLM running"
        case status ''
            if launchctl print $domain/$label >/dev/null 2>&1
                echo "local LLM: running"
                ollama ps 2>/dev/null
            else if launchctl print-disabled $domain | string match -q "*\"$label\" => disabled*"
                echo "local LLM: paused"
            else
                echo "local LLM: not loaded"
            end
        case '*'
            echo "Usage: local-llm [off|on|status]"
            return 1
    end
end
