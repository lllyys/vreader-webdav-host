#!/usr/bin/env bash
# Mirror local WebDAV data dir to iCloud Drive with rolling history.
# Invoked hourly by launchd. Sources $CONFIG_DIR/env so the same overrides
# (DATA_DIR, ICLOUD_DIR, PORT) the user gave to setup.sh are honored here too.

set -euo pipefail

CONFIG_DIR="$HOME/.config/vreader-webdav-host"
[[ -f "$CONFIG_DIR/env" ]] && source "$CONFIG_DIR/env"

DATA_DIR="${VREADER_DATA_DIR:-$HOME/vreader-webdav-data}"
ICLOUD_DIR="${VREADER_ICLOUD_DIR:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/VReaderBackups}"
ARCHIVE_DIR="${ICLOUD_DIR%/}-archive/$(date -u +%FT%H%M%SZ)"

mkdir -p "$ICLOUD_DIR"
rclone sync "$DATA_DIR" "$ICLOUD_DIR" \
  --backup-dir "$ARCHIVE_DIR" \
  --quiet
