#!/usr/bin/env bash
# Force re-read of newly rendered plists by bootout-then-bootstrap.
# `launchctl kickstart` only restarts an already-loaded definition — it would
# silently ignore a re-rendered plist. Idempotent in both fresh and upgrade paths.
set -euo pipefail

CONFIG_DIR="$HOME/.config/vreader-webdav-host"
DOMAIN="gui/$(id -u)"

for label in com.vreader.webdav com.vreader.icloud-sync; do
  # Tear down if already loaded; ignore failure on first install.
  launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
done
for label in com.vreader.webdav com.vreader.icloud-sync; do
  launchctl bootstrap "$DOMAIN" "$CONFIG_DIR/$label.plist"
done

echo "Started com.vreader.webdav and com.vreader.icloud-sync (forced reload)."
