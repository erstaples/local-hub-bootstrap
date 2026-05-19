#!/usr/bin/env bash
set -uo pipefail  # not -e: we want to keep checking even when something fails

ok()   { printf '\033[1;32m  ok\033[0m  %s\n' "$*"; }
fail() { printf '\033[1;31mfail\033[0m  %s\n' "$*"; failures=$((failures+1)); }
section() { printf '\n\033[1;34m== %s ==\033[0m\n' "$*"; }

failures=0

section "platform"
[[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]] \
  && ok "macOS arm64 ($(sw_vers -productVersion))" \
  || fail "not macOS arm64"

section "homebrew"
command -v brew >/dev/null && ok "brew at $(command -v brew)" || fail "brew missing"

section "power"
sleep_val="$(pmset -g custom 2>/dev/null | awk '/^AC Power:/{ac=1; next} ac && /sleep/{print $2; exit}')"
[[ "${sleep_val:-x}" == "0" ]] && ok "AC sleep = 0" || fail "AC sleep is '$sleep_val', expected 0"
womp_val="$(pmset -g custom 2>/dev/null | awk '/^AC Power:/{ac=1; next} ac && /womp/{print $2; exit}')"
[[ "${womp_val:-x}" == "1" ]] && ok "wake-on-network on" || fail "womp is '$womp_val'"

section "amphetamine"
[[ -d /Applications/Amphetamine.app ]] && ok "Amphetamine.app present" || fail "Amphetamine not installed"

section "tailscale"
if command -v tailscale >/dev/null; then
  state="$(tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo Unknown)"
  [[ "$state" == "Running" ]] && ok "tailscale Running, ip=$(tailscale ip -4 2>/dev/null)" || fail "tailscale state=$state"
else
  fail "tailscale CLI missing"
fi

section "ollama"
if command -v ollama >/dev/null; then
  if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    ok "ollama server responding"
    models="$(ollama list 2>/dev/null | awk 'NR>1 {print $1}' | paste -sd, -)"
    [[ -n "$models" ]] && ok "models: $models" || fail "no models pulled"
  else
    fail "ollama server not responding on 11434"
  fi
else
  fail "ollama CLI missing"
fi

section "ssh / spark"
[[ -f "$HOME/.ssh/id_ed25519_spark" ]] && ok "spark ssh key present" || fail "spark ssh key missing"
[[ -f "$HOME/.ssh/config.d/spark" ]] && ok "spark ssh host stub present" || fail "spark ssh host stub missing"
if ssh -o BatchMode=yes -o ConnectTimeout=3 spark true 2>/dev/null; then
  ok "spark SSH reachable"
else
  fail "spark SSH not reachable (expected before first connect)"
fi

section "hub routing"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
[[ -x "$REPO_DIR/bin/hub-ollama" ]] && ok "hub-ollama present" || fail "hub-ollama missing"
[[ -x "$REPO_DIR/bin/hub-tunnel" ]] && ok "hub-tunnel present"  || fail "hub-tunnel missing"
[[ -f "$REPO_DIR/config/model-routes.conf" ]] && ok "model-routes.conf present" || fail "model-routes.conf missing"
if "$REPO_DIR/bin/hub-tunnel" status >/dev/null 2>&1; then
  ok "spark tunnel up on 11435"
else
  ok "spark tunnel down (bring up with: hub-tunnel up)"
fi

section "hermes presets"
if command -v ollama >/dev/null && ollama list 2>/dev/null | awk '{print $1}' | grep -qx 'hermes-hub:8b'; then
  ok "hermes-hub:8b built locally"
else
  fail "hermes-hub:8b not built (run scripts/09-hermes-config.sh)"
fi
if ssh -o BatchMode=yes -o ConnectTimeout=3 spark true 2>/dev/null; then
  if ssh spark "ollama list 2>/dev/null | awk '{print \$1}' | grep -qx 'hermes-hub:70b'"; then
    ok "hermes-hub:70b built on spark"
  else
    fail "hermes-hub:70b not built on spark (run scripts/09-hermes-config.sh)"
  fi
fi

section "summary"
if (( failures == 0 )); then
  printf '\033[1;32mall good\033[0m\n'
  exit 0
else
  printf '\033[1;31m%d check(s) failed\033[0m\n' "$failures"
  exit 1
fi
