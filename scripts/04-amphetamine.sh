#!/usr/bin/env bash
set -euo pipefail

log() { printf '\033[1;34m   ->\033[0m %s\n' "$*"; }

AMPHETAMINE_ID=937984704

if ! command -v mas >/dev/null 2>&1; then
  log "mas not found; install Homebrew step first"
  exit 1
fi

# `mas` requires that the user is signed into the App Store via the GUI on
# modern macOS — sign-in via CLI was removed years ago.
if ! mas account >/dev/null 2>&1; then
  log "sign into the App Store first (open App Store.app and sign in), then re-run this script"
  open -a "App Store"
  exit 1
fi

if mas list | grep -q "^${AMPHETAMINE_ID}\b"; then
  log "Amphetamine already installed"
else
  log "installing Amphetamine from Mac App Store"
  mas install "$AMPHETAMINE_ID"
fi

log "launching Amphetamine so you can grant accessibility/login-item permissions"
open -a Amphetamine || true

cat <<'EOF'

  Next steps inside Amphetamine:
    1. Preferences > General > "Launch at login" = on
    2. Preferences > Sessions > enable "Allow display sleep" if you want
       the screen off while the machine stays awake
    3. Triggers > "When power source is AC" > start an indefinite session
    4. Grant accessibility permission when prompted (System Settings >
       Privacy & Security > Accessibility)

EOF
