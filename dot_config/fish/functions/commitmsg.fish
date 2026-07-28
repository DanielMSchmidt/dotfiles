function commitmsg -d "Draft a Conventional Commits message from staged changes via the local model"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    if not command -q ollama
        echo "Error: ollama is not installed (declared in packages.yaml)."
        return 1
    end

    if test -z "$(git diff --staged --name-only)"
        echo "No staged changes. Stage something with 'git add' first."
        return 1
    end

    git diff --staged | ollama run $AI_LOCAL_MODEL "Write a concise Conventional Commits message for the following staged diff: a single imperative summary line under 72 characters, plus a short body only if the change needs explanation. Output only the commit message, with no code fences or commentary."
end
