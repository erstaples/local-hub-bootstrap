#!/usr/bin/env bash
set -euo pipefail

log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }

if ! command -v tailscale >/dev/null 2>&1; then
  log "tailscale CLI missing; expected from Brewfile. Re-run 02-homebrew.sh"
  exit 1
fi

# The cask installs the menubar app; launching it once registers the
# system extension and starts the daemon.
if [[ -d /Applications/Tailscale.app ]]; then
  log "launching Tailscale.app to register the system extension"
  open -ga Tailscale || true
  sleep 3
fi

status="$(tailscale status --json 2>/dev/null | jq -r '.BackendState' || echo Unknown)"
case "$status" in
  Running)
    log "tailscale already up: $(tailscale status --self=true --peers=false | head -1)"
    ;;
  *)
    log "bringing tailscale up (interactive browser auth)"
    log "advertising tag:hub and enabling Tailscale SSH"
    tailscale up \
      --ssh \
      --advertise-tags=tag:hub \
      --accept-routes \
      --operator="$USER"
    ;;
esac

log "tailnet IPv4: $(tailscale ip -4 2>/dev/null || echo 'not assigned yet')"
log "tailscale ready"
