#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }

SSH_DIR="$HOME/.ssh"
INCLUDE_DIR="$SSH_DIR/config.d"
SPARK_CONF="$INCLUDE_DIR/spark"

mkdir -p "$INCLUDE_DIR"
chmod 700 "$SSH_DIR" "$INCLUDE_DIR"

# Ensure the main ssh config sources our drop-in directory.
if [[ ! -f "$SSH_DIR/config" ]] || ! grep -q "Include config.d/\*" "$SSH_DIR/config"; then
  log "adding 'Include config.d/*' to ~/.ssh/config"
  {
    printf 'Include config.d/*\n\n'
    [[ -f "$SSH_DIR/config" ]] && cat "$SSH_DIR/config"
  } > "$SSH_DIR/config.new"
  mv "$SSH_DIR/config.new" "$SSH_DIR/config"
  chmod 600 "$SSH_DIR/config"
fi

if [[ ! -f "$SPARK_CONF" ]]; then
  log "writing SSH host stub to $SPARK_CONF"
  cp "$REPO_DIR/config/ssh_config.spark" "$SPARK_CONF"
  chmod 600 "$SPARK_CONF"
else
  log "$SPARK_CONF already exists, leaving it alone"
fi

# Generate an ed25519 key dedicated to the Spark if one doesn't exist.
SPARK_KEY="$SSH_DIR/id_ed25519_spark"
if [[ ! -f "$SPARK_KEY" ]]; then
  log "generating dedicated SSH key for the Spark at $SPARK_KEY"
  ssh-keygen -t ed25519 -f "$SPARK_KEY" -N "" -C "spark@$(hostname -s)"
fi

cat <<EOF

  Next steps for DGX Spark connectivity:
    1. Install Tailscale on the Spark and join the same tailnet, tag it
       'tag:spark'.
    2. Edit $SPARK_CONF and set HostName to the Spark's MagicDNS name
       (e.g. spark.tail-XXXX.ts.net).
    3. Copy the public key:
         ssh-copy-id -i $SPARK_KEY.pub spark
    4. Test:
         ssh spark 'nvidia-smi'
    5. Optional: forward the Spark's Ollama port to this Mac so local
       clients can hit large models transparently:
         ssh -fNL 11435:127.0.0.1:11434 spark
       Then point heavy clients at http://127.0.0.1:11435.

EOF
