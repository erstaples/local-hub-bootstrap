#!/usr/bin/env bash
set -euo pipefail

log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "this bootstrap targets macOS only"
[[ "$(uname -m)" == "arm64" ]]  || die "expected Apple Silicon (arm64); got $(uname -m)"

macos_version="$(sw_vers -productVersion)"
log "macOS $macos_version on $(uname -m)"

major="${macos_version%%.*}"
(( major >= 14 )) || die "macOS 14 (Sonoma) or newer required for M4 hardware; found $macos_version"

if ! sudo -n true 2>/dev/null; then
  log "sudo will prompt for your password during power-settings step"
fi

log "preflight ok"
