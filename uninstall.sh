#!/usr/bin/env bash
# Tear down launchd jobs. Leaves data dir + iCloud Drive contents intact.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$REPO_DIR/scripts/stop.sh"
rm -f "$HOME/.config/vreader-webdav-host/com.vreader.webdav.plist"
rm -f "$HOME/.config/vreader-webdav-host/com.vreader.icloud-sync.plist"
echo "Uninstalled launchd services. Data dir and iCloud Drive untouched."
echo "To remove credentials: rm -rf $HOME/.config/vreader-webdav-host/"
