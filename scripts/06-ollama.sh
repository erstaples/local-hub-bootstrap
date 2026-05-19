#!/usr/bin/env bash
set -euo pipefail

log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }

# Default models. Hermes 3 8B fits comfortably in 48 GB unified memory and
# leaves room for context and other workloads. Larger Hermes variants are
# meant to run on the DGX Spark; see scripts/07-dgx-spark.sh.
MODELS=(
  "hermes3:8b"
)

if ! command -v ollama >/dev/null 2>&1; then
  log "ollama CLI missing; expected from cask ollama-app in Brewfile"
  exit 1
fi

# Launch the menubar app so the server is running. The app starts the
# daemon on localhost:11434.
if [[ -d /Applications/Ollama.app ]]; then
  open -ga Ollama || true
fi

# Wait briefly for the server to come up.
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
