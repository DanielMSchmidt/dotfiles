function ai -d "One-shot prompt to the local coding model; reads piped stdin as context"
    if test (count $argv) -eq 0
        echo "Usage: ai <prompt>            # e.g. ai explain git rebase"
        echo "       command | ai <prompt>  # pipe context in"
        return 1
    end

    if not command -q ollama
        echo "Error: ollama is not installed (declared in packages.yaml)."
        return 1
    end

    # ollama run appends any piped stdin to the prompt as context.
    ollama run $AI_LOCAL_MODEL "$argv"
end
