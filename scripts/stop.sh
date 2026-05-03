#!/usr/bin/env bash
set -euo pipefail
launchctl bootout "gui/$(id -u)/com.vreader.webdav" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/com.vreader.icloud-sync" 2>/dev/null || true
echo "Stopped both launchd services."
