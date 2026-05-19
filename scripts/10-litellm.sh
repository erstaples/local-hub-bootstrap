#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }

LOG_DIR="$HOME/Library/Logs/local-hub"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST_TPL="$REPO_DIR/config/launchd/com.local-hub.litellm.plist.template"
PLIST="$LAUNCH_DIR/com.local-hub.litellm.plist"
TUNNEL_TPL="$REPO_DIR/config/launchd/com.local-hub.tunnel.plist.template"
TUNNEL_PLIST="$LAUNCH_DIR/com.local-hub.tunnel.plist"
CONFIG_FILE="$REPO_DIR/config/litellm.yaml"

mkdir -p "$LOG_DIR" "$LAUNCH_DIR"

# 1. Initialize the shared env file (master key) if needed.
"$REPO_DIR/bin/hub-env" init

# 2. Source it into ~/.zprofile so interactive shells see the key too.
if ! grep -q 'local-hub/env' "$HOME/.zprofile" 2>/dev/null; then
  log "sourcing hub env from ~/.zprofile"
  printf '\n[ -f "$HOME/.config/local-hub/env" ] && . "$HOME/.config/local-hub/env"\n' >> "$HOME/.zprofile"
fi

# 3. Install LiteLLM into an isolated pipx env.
if ! command -v pipx >/dev/null 2>&1; then
  log "pipx missing; expected from Brewfile. Re-run 02-homebrew.sh"
  exit 1
fi

if ! pipx list 2>/dev/null | grep -q '^   package litellm '; then
  log "installing litellm[proxy] via pipx"
  pipx install 'litellm[proxy]'
else
  log "litellm already installed; upgrading"
  pipx upgrade litellm >/dev/null || true
fi

PIPX_BIN="$(pipx environment --value PIPX_BIN_DIR 2>/dev/null || echo "$HOME/.local/bin")"
HOMEBREW_PREFIX="$(brew --prefix)"

# 4. Render the launchd plists.
render() {
  local tpl="$1" out="$2"
  sed \
    -e "s|__HOMEBREW_PREFIX__|$HOMEBREW_PREFIX|g" \
    -e "s|__PIPX_BIN__|$PIPX_BIN|g" \
    -e "s|__CONFIG_FILE__|$CONFIG_FILE|g" \
    -e "s|__ENV_FILE__|$HOME/.config/local-hub/env|g" \
    -e "s|__LOG_DIR__|$LOG_DIR|g" \
    "$tpl" > "$out"
}

log "writing $PLIST"
render "$PLIST_TPL" "$PLIST"

log "writing $TUNNEL_PLIST"
render "$TUNNEL_TPL" "$TUNNEL_PLIST"

# 5. Load them under the GUI launchd domain so they auto-start at login.
domain="gui/$(id -u)"
for plist in "$PLIST" "$TUNNEL_PLIST"; do
  label="$(basename "$plist" .plist)"
  if launchctl print "$domain/$label" >/dev/null 2>&1; then
    log "reloading $label"
    launchctl bootout  "$domain/$label" 2>/dev/null || true
  fi
  launchctl bootstrap "$domain" "$plist"
  launchctl kickstart -k "$domain/$label" || true
done

# 6. Wait briefly for LiteLLM to come up.
for _ in {1..15}; do
  if curl -fsS http://127.0.0.1:4000/health/liveliness >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if curl -fsS http://127.0.0.1:4000/health/liveliness >/dev/null 2>&1; then
  log "litellm proxy up at http://127.0.0.1:4000"
  log "list models: curl http://127.0.0.1:4000/v1/models -H \"Authorization: Bearer \$LITELLM_MASTER_KEY\""
else
  log "litellm did not respond yet; tail logs: tail -f $LOG_DIR/litellm.log"
fi
