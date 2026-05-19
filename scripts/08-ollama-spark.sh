#!/usr/bin/env bash
set -euo pipefail

log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m   ~~\033[0m %s\n' "$*"; exit 0; }

# Provisions Ollama on the DGX Spark over SSH and pulls hermes3:70b there.
# Depends on 07-dgx-spark.sh having configured the `spark` SSH alias and
# the Spark having joined the tailnet.

SPARK_HOST=spark
SPARK_MODEL="hermes3:70b"

# If the Spark isn't reachable yet, don't fail the whole bootstrap — this
# is the most common "do it later" step.
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SPARK_HOST" true 2>/dev/null; then
  skip "cannot reach '$SPARK_HOST' over SSH yet. Finish the steps in 07-dgx-spark.sh, then re-run this script."
fi

log "spark reachable; checking Ollama on remote"

# shellcheck disable=SC2087  # we want $SPARK_MODEL expanded locally
ssh "$SPARK_HOST" bash -s <<EOF
set -euo pipefail

if ! command -v ollama >/dev/null 2>&1; then
  echo "   -> installing Ollama on the Spark"
  curl -fsSL https://ollama.com/install.sh | sh
fi

# The installer registers a systemd service; make sure it's listening.
if ! systemctl is-active --quiet ollama 2>/dev/null; then
  sudo systemctl enable --now ollama
fi

# Wait for the local API on the Spark.
for _ in {1..20}; do
  if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then break; fi
  sleep 1
done

if ollama list | awk '{print \$1}' | grep -qx "$SPARK_MODEL"; then
  echo "   -> $SPARK_MODEL already present on Spark"
else
  echo "   -> pulling $SPARK_MODEL on Spark (this is ~40 GB; takes a while)"
  ollama pull "$SPARK_MODEL"
fi

ollama list
EOF

log "spark provisioned. start the local tunnel with: bin/hub-tunnel up"
log "then route a model via: bin/hub-ollama run $SPARK_MODEL 'hello'"
