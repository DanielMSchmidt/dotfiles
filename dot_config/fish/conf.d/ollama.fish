# Local LLM (Ollama) shell setup. Both machines run the stack; they differ only
# in which driver is pulled — see ollamaModels/ollamaDriver in
# .chezmoidata/packages.yaml.
#
# AI_LOCAL_MODEL (the model the ai/qc/commitmsg helpers use) and the OLLAMA_*
# server tuning live in .chezmoidata/shell.yaml so bash and zsh get them too.
# Override per-shell with `set -gx AI_LOCAL_MODEL qwen2.5-coder:3b` to trade
# quality for speed.

# Quick view of resident models and their memory footprint.
alias ollama-ps "ollama ps"

# Subcommands for the pause/resume helper (functions/local-llm.fish).
complete -c local-llm -f -n __fish_use_subcommand -a off -d "Stop the server and keep it off across reboots"
complete -c local-llm -f -n __fish_use_subcommand -a on -d "Re-enable and start the server"
complete -c local-llm -f -n __fish_use_subcommand -a status -d "Show whether the server is running"
