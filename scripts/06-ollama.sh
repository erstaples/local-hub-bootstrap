#!/usr/bin/env bash
set -euo pipefail

log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }

# Default local models on the Mac.
#  - gpt-oss:20b      — daily-driver, ~13 GB MXFP4, snappy on M4 Max
#  - hermes4:14b      — agentic fallback, ~9 GB Q4, strong tool-calling
# Heavier siblings (gpt-oss:120b, hermes4:70b) live on the Spark.
MODELS=(
  "gpt-oss:20b"
  "hermes4:14b"
)

if ! command -v ollama >/dev/null 2>&1; then
  log "ollama CLI missing; expected from cask ollama-app in Brewfile"
  exit 1
fi

# Launch the menubar app so the server is running.
if [[ -d /Applications/Ollama.app ]]; then
  open -ga Ollama || true
fi

# Wait for the API.
for _ in {1..15}; do
  if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  log "ollama server did not respond on 127.0.0.1:11434; start Ollama.app manually and re-run"
  exit 1
fi

for model in "${MODELS[@]}"; do
  if ollama list | awk '{print $1}' | grep -qx "$model"; then
    log "model $model already pulled"
  else
    log "pulling $model"
    ollama pull "$model"
  fi
done

log "ollama models available:"
ollama list
