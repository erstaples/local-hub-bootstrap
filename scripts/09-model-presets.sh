#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS_DIR="$REPO_DIR/config/models"
log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m   ~~\033[0m %s\n' "$*"; }

# Local presets — built on the Mac.
LOCAL_PRESETS=(
  "gpt-oss-hub:20b|$MODELS_DIR/Modelfile.gpt-oss-hub.20b|gpt-oss:20b"
  "hermes-hub:14b|$MODELS_DIR/Modelfile.hermes-hub.14b|hermes4:14b"
)

# Spark presets — built remotely over SSH.
SPARK_PRESETS=(
  "gpt-oss-hub:120b|$MODELS_DIR/Modelfile.gpt-oss-hub.120b|gpt-oss:120b"
  "hermes-hub:70b|$MODELS_DIR/Modelfile.hermes-hub.70b|hermes4:70b"
)

require_local_ollama() {
  command -v ollama >/dev/null 2>&1 \
    || { log "ollama missing locally; run scripts/06-ollama.sh first"; exit 1; }
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 \
    || { log "local ollama server not responding; start Ollama.app and re-run"; exit 1; }
}

build_local() {
  local tag="$1" mf="$2" base="$3"
  if ! ollama list | awk '{print $1}' | grep -qx "$base"; then
    log "base $base not pulled yet; run scripts/06-ollama.sh first"
    return 1
  fi
  log "building $tag from $(basename "$mf")"
  ollama create "$tag" -f "$mf"
}

build_remote() {
  local tag="$1" mf="$2" base="$3"
  if ! ssh spark "ollama list | awk '{print \$1}' | grep -qx '$base'"; then
    log "base $base not on Spark yet; run scripts/08-ollama-spark.sh first"
    return 1
  fi
  log "building $tag on spark from $(basename "$mf")"
  ssh spark "ollama create '$tag' -f -" < "$mf"
}

require_local_ollama
for entry in "${LOCAL_PRESETS[@]}"; do
  IFS='|' read -r tag mf base <<<"$entry"
  build_local "$tag" "$mf" "$base"
done

if ssh -o BatchMode=yes -o ConnectTimeout=5 spark true 2>/dev/null; then
  for entry in "${SPARK_PRESETS[@]}"; do
    IFS='|' read -r tag mf base <<<"$entry"
    build_remote "$tag" "$mf" "$base"
  done
else
  skip "spark not reachable; skipping Spark presets. Re-run after the Spark joins the tailnet."
fi

# Make sure routing config covers every Spark-side model name.
ROUTES="$REPO_DIR/config/model-routes.conf"
for tag in "gpt-oss-hub:120b" "hermes-hub:70b" "gpt-oss:120b" "hermes4:70b"; do
  if ! grep -q "^${tag}=" "$ROUTES"; then
    log "adding $tag route to $ROUTES"
    printf '%s=http://127.0.0.1:11435\n' "$tag" >> "$ROUTES"
  fi
done

log "presets ready. Try:"
log "  hub-ollama run gpt-oss-hub:20b  'hello'   # local default"
log "  hub-ollama run hermes-hub:14b   'hello'   # local agent"
log "  hub-ollama run gpt-oss-hub:120b 'hello'   # spark heavy reasoner"
log "  hub-ollama run hermes-hub:70b   'hello'   # spark heavy agent"
