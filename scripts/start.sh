#!/usr/bin/env bash
# Force re-read of newly rendered plists by bootout-then-bootstrap.
# `launchctl kickstart` only restarts an already-loaded definition — it would
# silently ignore a re-rendered plist. Idempotent in both fresh and upgrade paths.
#
# Sonoma+ quirk: `launchctl bootstrap` sometimes returns exit 1 with
# "Bootstrap failed: 5: Input/output error" even when the load actually
# succeeded async. Trusting the exit code surfaces those false negatives as
# install failures. Instead, ignore the bootstrap exit code and verify each
# job via `launchctl print` — the only authoritative signal that the job is
# loaded in the domain. This script reports "Loaded" (not "Healthy") because
# load ≠ usable: a loaded webdav job with bad args can crash-loop under
# KeepAlive and still print as loaded. setup.sh runs status.sh after this,
# which does the PROPFIND probe to confirm the server is actually serving.
set -euo pipefail

CONFIG_DIR="$HOME/.config/vreader-webdav-host"
DOMAIN="gui/$(id -u)"
LABELS=(com.vreader.webdav com.vreader.icloud-sync)

# Per-label temp file capturing the latest bootstrap stderr — used in the
# timeout diagnostic to surface the real launchd reason (malformed plist,
# bad path, etc.) rather than just "failed to load".
TMPDIR_BOOT="$(mktemp -d -t vreader-launchctl.XXXXXX)"
trap 'rm -rf "$TMPDIR_BOOT"' EXIT

for label in "${LABELS[@]}"; do
  # Bootout is best-effort and asynchronous: missing labels exit non-zero
  # (fine), and even on success the label can linger in `launchctl print` for
  # a few seconds while the SIGTERM-driven shutdown completes. Poll until the
  # label is gone, up to ~5s. A label that's STILL loaded after that is a
  # real problem — bootstrapping onto a stale definition would mean `print`
  # later lies about freshness.
  launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
  bootout_deadline=$(( $(date +%s) + 5 ))
  while launchctl print "$DOMAIN/$label" >/dev/null 2>&1; do
    if (( $(date +%s) >= bootout_deadline )); then
      echo "ERROR: $label still loaded 5s after bootout — refusing to continue with stale plist." >&2
      echo "Diagnose: launchctl print $DOMAIN/$label" >&2
      exit 1
    fi
    sleep 0.25
  done
done

for label in "${LABELS[@]}"; do
  # Capture stderr for the timeout diagnostic; ignore exit code (Sonoma EIO false negative).
  launchctl bootstrap "$DOMAIN" "$CONFIG_DIR/$label.plist" 2>"$TMPDIR_BOOT/$label.err" || true
done

# Poll for load completion — bootstrap's async cleanup on Sonoma+ can take a
# few seconds, so a single sleep isn't reliable. Up to ~10s with 250ms ticks.
deadline=$(( $(date +%s) + 10 ))
while :; do
  failed=()
  for label in "${LABELS[@]}"; do
    if ! launchctl print "$DOMAIN/$label" >/dev/null 2>&1; then
      failed+=("$label")
    fi
  done
  if (( ${#failed[@]} == 0 )); then break; fi
  if (( $(date +%s) >= deadline )); then
    echo "ERROR: failed to load after 10s: ${failed[*]}" >&2
    for label in "${failed[@]}"; do
      err="$TMPDIR_BOOT/$label.err"
      if [[ -s "$err" ]]; then
        echo "--- launchctl bootstrap stderr for $label ---" >&2
        cat "$err" >&2
      fi
    done
    echo "Also check: launchctl print $DOMAIN/<label> and Console.app." >&2
    exit 1
  fi
  sleep 0.25
done

echo "Loaded ${LABELS[*]} (forced reload). Run status.sh for a health check."
