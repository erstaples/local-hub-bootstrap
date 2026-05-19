#!/usr/bin/env bash
set -euo pipefail

log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m   ~~\033[0m %s\n' "$*"; exit 0; }

# Provisions Ollama on the DGX Spark over SSH and pulls the heavy models
# there. Depends on 07-dgx-spark.sh having configured the `spark` SSH
# alias and the Spark having joined the tailnet.

SPARK_HOST=spark
SPARK_MODELS=(
  "gpt-oss:120b"    # ~63 GB MXFP4, native fit for 128 GB unified memory
  "hermes4:70b"     # ~40 GB Q4, leaves room for 32k+ context
)

# If the Spark isn't reachable yet, don't fail the whole bootstrap.
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SPARK_HOST" true 2>/dev/null; then
  skip "cannot reach '$SPARK_HOST' over SSH yet. Finish 07-dgx-spark.sh, then re-run this script."
fi

log "spark reachable; provisioning Ollama and pulling heavy models"

# shellcheck disable=SC2087  # we want array expansion to happen locally
ssh "$SPARK_HOST" bash -s -- "${SPARK_MODELS[@]}" <<'REMOTE'
set -euo pipefail

if ! command -v ollama >/dev/null 2>&1; then
  echo "   -> installing Ollama on the Spark"
  curl -fsSL https://ollama.com/install.sh | sh
fi

if ! systemctl is-active --quiet ollama 2>/dev/null; then
  sudo systemctl enable --now ollama
fi

for _ in {1..20}; do
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break
  sleep 1
done

for model in "$@"; do
  if ollama list | awk '{print $1}' | grep -qx "$model"; then
    echo "   -> $model already present on Spark"
  else
    echo "   -> pulling $model on Spark"
    ollama pull "$model"
  fi
done

ollama list
REMOTE

log "spark provisioned. start the local tunnel with: hub-tunnel up"
log "then route via: hub-ollama run gpt-oss-hub:120b 'hello'"
