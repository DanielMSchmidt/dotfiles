# Local LLM (Ollama) shell setup for a 16GB Apple Silicon machine.
#
# AI_LOCAL_MODEL (the model the ai/qc/commitmsg helpers use) and the OLLAMA_*
# server tuning live in .chezmoidata/shell.yaml so bash and zsh get them too.
# Override per-shell with `set -gx AI_LOCAL_MODEL qwen2.5-coder:3b` to trade
# quality for speed.

# Quick view of resident models and their memory footprint.
alias ollama-ps "ollama ps"
