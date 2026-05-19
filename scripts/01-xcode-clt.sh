#!/usr/bin/env bash
set -euo pipefail

log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }

if xcode-select -p >/dev/null 2>&1; then
  log "Xcode Command Line Tools already installed at $(xcode-select -p)"
  exit 0
fi

log "installing Xcode Command Line Tools (GUI prompt will appear)"
xcode-select --install || true

# Wait for installation to complete.
until xcode-select -p >/dev/null 2>&1; do
  sleep 10
  log "waiting for CLT install to finish..."
done

log "Xcode CLT ready at $(xcode-select -p)"
