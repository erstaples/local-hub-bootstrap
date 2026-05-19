#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m   ~~\033[0m %s\n' "$*"; }

LOCAL_MF="$REPO_DIR/config/hermes/Modelfile.hub-8b"
SPARK_MF="$REPO_DIR/config/hermes/Modelfile.hub-70b"

# --- Local: build hermes-hub:8b -------------------------------------------
if ! command -v ollama >/dev/null 2>&1; then
  log "ollama missing locally; run scripts/06-ollama.sh first"
  exit 1
fi

if ! curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  log "local ollama server not responding; start Ollama.app and re-run"
  exit 1
fi

if ! ollama list | awk '{print $1}' | grep -qx 'hermes3:8b'; then
  log "base model hermes3:8b not pulled yet; run scripts/06-ollama.sh first"
  exit 1
fi

log "building hermes-hub:8b from $LOCAL_MF"
ollama create hermes-hub:8b -f "$LOCAL_MF"

# --- Spark: build hermes-hub:70b ------------------------------------------
if ssh -o BatchMode=yes -o ConnectTimeout=5 spark true 2>/dev/null; then
  log "applying hermes-hub:70b on the Spark"
  # Stream the Modelfile to the Spark and build from stdin.
  ssh spark "ollama create hermes-hub:70b -f -" < "$SPARK_MF"
else
  skip "spark not reachable; skipping hermes-hub:70b. Re-run after the Spark joins the tailnet."
fi

# --- Route the customized 70B variant through the tunnel too --------------
ROUTES="$REPO_DIR/config/model-routes.conf"
if ! grep -q '^hermes-hub:70b=' "$ROUTES"; then
  log "adding hermes-hub:70b route to $ROUTES"
  printf 'hermes-hub:70b=http://127.0.0.1:11435\n' >> "$ROUTES"
fi

log "hermes presets ready. Try: hub-ollama run hermes-hub:8b 'hello'"
