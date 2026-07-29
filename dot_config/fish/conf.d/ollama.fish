# Local LLM (Ollama) shell setup for a 16GB Apple Silicon machine.

# Default coding model used by the ai/qc/commitmsg helpers. Override per-shell
# with `set -gx AI_LOCAL_MODEL qwen2.5-coder:3b` to trade quality for speed.
set -x AI_LOCAL_MODEL qwen3.5:9b

# Server tuning, applied when `ollama serve` is launched from a shell. The
# always-on server runs via a LaunchAgent that carries the same values (see
# Library/LaunchAgents/com.danielschmidt.ollama.plist).
set -x OLLAMA_FLASH_ATTENTION 1
set -x OLLAMA_KV_CACHE_TYPE q8_0
set -x OLLAMA_CONTEXT_LENGTH 32768

# Quick view of resident models and their memory footprint.
alias ollama-ps "ollama ps"
