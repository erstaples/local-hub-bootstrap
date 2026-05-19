#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }

if ! command -v brew >/dev/null 2>&1; then
  log "installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apple Silicon Homebrew lives in /opt/homebrew; make sure it's on PATH for this run.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Persist shellenv in zprofile if it's not already there.
if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
  log "adding brew shellenv to ~/.zprofile"
  printf '\neval "$(/opt/homebrew/bin/brew shellenv)"\n' >> "$HOME/.zprofile"
fi

# Put this repo's bin/ on PATH so hub-ollama and hub-tunnel are available.
if ! grep -q "local-hub-bootstrap/bin" "$HOME/.zprofile" 2>/dev/null; then
  log "adding $REPO_DIR/bin to PATH via ~/.zprofile"
  printf '\nexport PATH="%s/bin:$PATH"\n' "$REPO_DIR" >> "$HOME/.zprofile"
fi

log "brew at $(command -v brew)"
log "running brew bundle from config/Brewfile"
brew bundle --file="$REPO_DIR/config/Brewfile"

log "homebrew ready"
