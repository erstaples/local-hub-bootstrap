#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }
COMPOSE_DIR="$REPO_DIR/config/open-webui"

if ! command -v docker >/dev/null 2>&1; then
  log "docker CLI missing; expected from cask docker-desktop. Re-run 02-homebrew.sh"
  exit 1
fi

# Docker Desktop must be running for the compose stack to start. Launch
# the app and wait for the engine to become responsive.
if ! docker info >/dev/null 2>&1; then
  log "starting Docker Desktop"
  open -ga "Docker"
  for _ in {1..60}; do
    docker info >/dev/null 2>&1 && break
    sleep 2
  done
fi
docker info >/dev/null 2>&1 || { log "Docker still not responding; start Docker.app manually and re-run"; exit 1; }

# Make sure the master key is in our shell so docker compose interpolation sees it.
[[ -f "$HOME/.config/local-hub/env" ]] || "$REPO_DIR/bin/hub-env" init
# shellcheck disable=SC1091
. "$HOME/.config/local-hub/env"

log "bringing up Open WebUI stack"
docker compose -f "$COMPOSE_DIR/docker-compose.yml" pull
docker compose -f "$COMPOSE_DIR/docker-compose.yml" up -d

# Wait for the UI.
for _ in {1..30}; do
  if curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1; then break; fi
  sleep 2
done

if curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1; then
  log "Open WebUI ready at http://127.0.0.1:8080"
else
  log "Open WebUI did not respond yet; container is starting (this is normal on first run)."
  log "watch with: docker compose -f $COMPOSE_DIR/docker-compose.yml logs -f"
fi

cat <<'EOF'

  Make Open WebUI always-on:
    1. Docker Desktop > Settings > General > "Start Docker Desktop when
       you log in" — turn on.
    2. The compose stack uses restart: unless-stopped, so Open WebUI
       comes back automatically once Docker Desktop is up.

EOF
