#!/usr/bin/env bash
set -euo pipefail

log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }

log "applying always-on pmset profile (sudo required)"

# Apply to AC profile (-c). Battery (-b) keeps defaults to preserve runtime
# when unplugged, since this is still a laptop.
sudo pmset -c sleep 0              # system never sleeps on AC
sudo pmset -c disksleep 0          # disks never spin down on AC
sudo pmset -c displaysleep 10      # display can sleep after 10 min
sudo pmset -c powernap 1           # power nap for background tasks
sudo pmset -c womp 1               # wake on network access
sudo pmset -c autorestart 1        # auto-restart after power failure
sudo pmset -c tcpkeepalive 1       # keep TCP connections alive
sudo pmset -c hibernatemode 0      # no hibernate; ram-only sleep when sleeping

# Disable sleep entirely while plugged in (Big Sur+). This is the modern
# replacement for `caffeinate -d`-style hacks; works with the lid closed.
sudo pmset -c disablesleep 1 || log "disablesleep flag not accepted on this OS; rely on Amphetamine for lid-closed"

log "current pmset settings:"
pmset -g custom || pmset -g

log "power settings applied"
