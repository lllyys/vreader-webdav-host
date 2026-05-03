#!/usr/bin/env bash
# Mirror local WebDAV data dir to iCloud Drive with rolling history.
# Invoked hourly by launchd. Sources $CONFIG_DIR/env so the same overrides
# (DATA_DIR, ICLOUD_DIR, PORT) the user gave to setup.sh are honored here too.

set -euo pipefail

CONFIG_DIR="$HOME/.config/vreader-webdav-host"
[[ -f "$CONFIG_DIR/env" ]] && source "$CONFIG_DIR/env"

# launchd's stripped PATH (/usr/bin:/bin:/usr/sbin:/sbin) doesn't include
# /opt/homebrew/bin, so prefer the absolute path setup.sh discovered. Fall back
# to PATH lookup so a manual run from the user's shell still works.
RCLONE_BIN="${VREADER_RCLONE_BIN:-rclone}"
DATA_DIR="${VREADER_DATA_DIR:-$HOME/vreader-webdav-data}"
ICLOUD_DIR="${VREADER_ICLOUD_DIR:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/VReaderBackups}"
ARCHIVE_DIR="${ICLOUD_DIR%/}-archive/$(date -u +%FT%H%M%SZ)"

# Preflight: under launchd a missing rclone would surface as a cryptic
# "command not found" deep in the sync call. Fail loud here instead so the
# /tmp/vreader-icloud-sync.err line clearly names the var.
if ! command -v "$RCLONE_BIN" >/dev/null 2>&1; then
  echo "ERROR: rclone binary not found at '$RCLONE_BIN'." >&2
  echo "  VREADER_RCLONE_BIN is set in $HOME/.config/vreader-webdav-host/env." >&2
  echo "  Re-run setup.sh from the repo to regenerate it." >&2
  exit 127
fi

mkdir -p "$ICLOUD_DIR"
"$RCLONE_BIN" sync "$DATA_DIR" "$ICLOUD_DIR" \
  --backup-dir "$ARCHIVE_DIR" \
  --quiet
