function qc -d "Interactive chat with the local coding model (qwen2.5-coder)"
    if not command -q ollama
        echo "Error: ollama is not installed (declared in packages.yaml)."
        return 1
    end
    ollama run $AI_LOCAL_MODEL $argv
end
