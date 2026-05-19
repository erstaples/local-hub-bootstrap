#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

log "local-hub bootstrap starting from $REPO_DIR"

shopt -s nullglob
for step in "$SCRIPTS_DIR"/[0-9][0-9]-*.sh; do
  name="$(basename "$step")"
  log "running $name"
  bash "$step"
done

log "bootstrap complete. follow post-install steps in README.md."
