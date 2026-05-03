#!/usr/bin/env bash
# Smoke-check both launchd jobs, the WebDAV endpoint (PROPFIND, not GET — should
# return 401 unauthenticated), and Tailscale presence + node identity.
set -euo pipefail

CONFIG_DIR="$HOME/.config/vreader-webdav-host"
[[ -f "$CONFIG_DIR/env" ]] && source "$CONFIG_DIR/env"
PORT="${VREADER_PORT:-8080}"
DOMAIN="gui/$(id -u)"

echo "--- launchd ---"
for label in com.vreader.webdav com.vreader.icloud-sync; do
  if launchctl print "$DOMAIN/$label" >/dev/null 2>&1; then
    echo "  $label: loaded"
  else
    echo "  $label: NOT loaded"
  fi
done

echo
echo "--- HTTP smoke (PROPFIND on /) ---"
# Assignment-style fallback: curl already prints '000' on connection failure;
# `|| echo "000"` would have appended a SECOND "000" producing "000000".
http_code="$(curl -s -o /dev/null -w '%{http_code}' -X PROPFIND -H 'Depth: 0' "http://127.0.0.1:$PORT/")" || http_code="000"
case "$http_code" in
  401) echo "  HTTP $http_code — auth required (expected; server is up)";;
  207|200) echo "  HTTP $http_code — server responded (auth bypass? unexpected for unauthenticated PROPFIND)";;
  000) echo "  unreachable — check launchd logs at /tmp/vreader-webdav.log";;
  *) echo "  HTTP $http_code — unexpected, investigate";;
esac

echo
echo "--- Tailscale ---"
if command -v tailscale >/dev/null 2>&1; then
  # Prefer the JSON .Self.DNSName via jq when present; otherwise parse the
  # "(self)" line from `tailscale status` plain output.
  ts_self_name=""
  if command -v jq >/dev/null 2>&1; then
    ts_self_name="$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' 2>/dev/null || true)"
  fi
  if [[ -z "$ts_self_name" ]]; then
    ts_self_name="$(tailscale status 2>/dev/null | awk '/\(self\)/ {print $2; exit}' || true)"
  fi
  if [[ -n "$ts_self_name" ]]; then
    echo "  this node: $ts_self_name"
    echo "  vreader URL to use: http://${ts_self_name%.}:$PORT"
  else
    echo "  tailscale installed but no current identity (run: tailscale up)"
  fi
else
  echo "  tailscale not installed — install for off-LAN reach (https://tailscale.com/download/mac)"
fi
