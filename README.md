# vreader-webdav-host

Self-hosted WebDAV server on a Mac, fronting [vreader](https://github.com/lllyys/vreader)'s WebDAV backup feature. One process, one binary: `rclone serve webdav`. Reachable on local LAN and via Tailscale's MagicDNS. iCloud Drive holds an hourly mirror as the durable backup tier. The repo ships templates and install scripts only — no real credentials, hostnames, or paths.

## Quick-start

```bash
git clone https://github.com/lllyys/vreader-webdav-host.git
cd vreader-webdav-host
./setup.sh
```

`setup.sh` will:

1. Preflight-check `htpasswd`, `launchctl`, `curl`. Install `rclone` via Homebrew if missing.
2. Prompt for a WebDAV username and create `~/.config/vreader-webdav-host/htpasswd` (bcrypt).
3. Render the launchd plists from `launchd/*.plist.template` into `~/.config/vreader-webdav-host/`.
4. Copy `scripts/*.sh` into `~/.config/vreader-webdav-host/scripts/` so launchd keeps working even if you move or delete the repo.
5. `bootout`-then-`bootstrap` both launchd jobs (forces re-read of the rendered plists).
6. Run `scripts/status.sh` as a smoke test.

When it finishes, paste the URL it prints (`http://<tailscale-host>:8080` or `http://127.0.0.1:8080` on the LAN) into vreader's WebDAV settings. Use the username and password you just set.

## Architecture

```
 vreader (iOS) ──── HTTP ────► rclone serve webdav ──► ~/vreader-webdav-data/
                                       (port 8080)             │
                                                               │  hourly
                                                               ▼
                                                   ~/Library/Mobile Documents/
                                                   com~apple~CloudDocs/
                                                   VReaderBackups/
```

- **WebDAV server.** `rclone serve webdav` runs as a `gui/<uid>` LaunchAgent (`com.vreader.webdav`), bound to `0.0.0.0:8080`, authenticating via the htpasswd file. `KeepAlive=true` so it restarts on crash.
- **Reach.** Local LAN works directly. Off-LAN reach is via [Tailscale](https://tailscale.com) — the Mac's MagicDNS hostname is the URL you put into vreader. Tailscale handles the encryption; the underlying server speaks plain HTTP. **No public ingress, no port forwarding, no TLS.**
- **iCloud sync.** A second LaunchAgent (`com.vreader.icloud-sync`, `StartInterval=3600`) runs `scripts/icloud-sync.sh` every hour. That script `rclone sync`s the local data dir to iCloud Drive with a per-run `--backup-dir` for rolling history. The local dir is *not* mounted under iCloud Drive directly — macOS file eviction makes that brittle.
- **State.** Real config (htpasswd, rendered plists, env file, copied scripts) lives in `~/.config/vreader-webdav-host/`. Data lives in `~/vreader-webdav-data/`. iCloud mirror lives in `~/Library/Mobile Documents/com~apple~CloudDocs/VReaderBackups/` with archive history at `…VReaderBackups-archive/<UTC-timestamp>/`.

## File layout

```
.
├── README.md                           This file.
├── AGENTS.md                           Working agreement for AI agents on this repo.
├── CLAUDE.md                           One-line pointer to AGENTS.md.
├── setup.sh                            Idempotent installer; refuses on placeholder sentinel.
├── uninstall.sh                        Tear down launchd jobs (data/iCloud preserved).
├── VERSION                             Plain-text semver — single source of truth.
├── .gitignore                          Excludes real htpasswd + rendered plists.
├── .gitleaks.toml                      Secret-scan rules (htpasswd hash, tskey, basic-auth header).
├── .github/workflows/secret-scan.yml   gitleaks Action on every push.
├── config/
│   └── htpasswd.example                Sentinel-only example; real htpasswd is outside the repo.
├── launchd/
│   ├── com.vreader.webdav.plist.template       rclone serve webdav.
│   └── com.vreader.icloud-sync.plist.template  Hourly icloud-sync.sh.
├── scripts/
│   ├── start.sh                        bootout-then-bootstrap; forces plist re-read.
│   ├── stop.sh                         bootout both jobs.
│   ├── status.sh                       launchd state + PROPFIND smoke + Tailscale identity.
│   └── icloud-sync.sh                  rclone sync to iCloud, with --backup-dir history.
└── .claude/
    └── rules/
        ├── 24-doc-sync.md              When to update this README.
        └── 40-version-bump.md          VERSION-file bump procedure.
```

## Operations

| Task                           | Command                                           |
| ------------------------------ | ------------------------------------------------- |
| Install / re-install / repair  | `./setup.sh`                                      |
| Health check                   | `~/.config/vreader-webdav-host/scripts/status.sh` |
| Stop both services             | `~/.config/vreader-webdav-host/scripts/stop.sh`   |
| Restart (after editing config) | `./setup.sh` (re-renders + reloads)               |
| Tear down launchd jobs         | `./uninstall.sh`                                  |
| Wipe credentials               | `rm -rf ~/.config/vreader-webdav-host/`           |

Logs:

- WebDAV server: `/tmp/vreader-webdav.log`, `/tmp/vreader-webdav.err`
- iCloud sync: `/tmp/vreader-icloud-sync.log`, `/tmp/vreader-icloud-sync.err`

The logs go to `/tmp` deliberately — macOS rotates `/tmp` on reboot, which is fine for a v0.x where there's no log-volume problem to solve yet.

## Security posture

- **No public ingress.** The server binds to `0.0.0.0:8080` so it's reachable on the LAN and on the Tailscale tailnet. There is no port forwarding step, no DNS record, no public TLS cert.
- **No TLS on the WebDAV server.** Tailscale provides WireGuard encryption between nodes; on the LAN the assumption is that the LAN itself is trusted. Adding TLS to a `rclone serve webdav` would require a cert chain that this recipe is intentionally avoiding.
- **Basic auth via htpasswd.** Bcrypt hash, file mode `600`, lives at `~/.config/vreader-webdav-host/htpasswd`. The repo never sees the real hash — `config/htpasswd.example` carries a `REPLACE_ME_PLACEHOLDER` sentinel that `setup.sh` actively rejects.
- **No Tailscale auth keys committed.** This repo only *reads* Tailscale state (in `scripts/status.sh`). It never runs `tailscale up`, never authenticates, never modifies the tailnet. Bring your own Tailscale install.
- **gitleaks on every push.** `.github/workflows/secret-scan.yml` runs the [gitleaks Action](https://github.com/gitleaks/gitleaks-action) using `.gitleaks.toml`, which adds rules for htpasswd bcrypt hashes, `tskey-…` Tailscale auth keys, and raw `Authorization: Basic` headers. The placeholder sentinel is allowlisted by content (not by path), so a real bcrypt hash anywhere in the repo would still trip the scan.

## Troubleshooting

#### `rclone: command not found` from `setup.sh` itself

`setup.sh` only installs rclone via Homebrew if rclone is absent. If you don't have Homebrew, install rclone manually per <https://rclone.org/install/> and rerun.

#### `/tmp/vreader-icloud-sync.err` says `rclone: command not found`

Different cause from the entry above: `rclone` is installed, but launchd's stripped PATH (`/usr/bin:/bin:/usr/sbin:/sbin`) doesn't include `/opt/homebrew/bin` (Apple Silicon Homebrew) or `/usr/local/bin` (Intel Homebrew), so the launchd-spawned `icloud-sync.sh` can't find the binary.

v0.1.1+ persists the absolute rclone path `setup.sh` discovered into `~/.config/vreader-webdav-host/env` as `VREADER_RCLONE_BIN`, and `icloud-sync.sh` uses that. If you see this error, the env file is missing or stale — re-run `./setup.sh` to regenerate it. Verify after re-run:

```bash
grep VREADER_RCLONE_BIN ~/.config/vreader-webdav-host/env
# expected: export VREADER_RCLONE_BIN=/opt/homebrew/bin/rclone (or your rclone install path)
```

#### `ERROR: $CONFIG_DIR/htpasswd still contains the placeholder sentinel`

Means a previous attempt left a sentinel-laden file behind, or you copied `config/htpasswd.example` into `~/.config/vreader-webdav-host/htpasswd` directly. Replace it with a real one:

```bash
htpasswd -B -c ~/.config/vreader-webdav-host/htpasswd youruser
```

Then rerun `./setup.sh`.

#### `launchctl bootstrap … : Input/output error` on macOS Sonoma+

This is a Sonoma+ async-cleanup quirk where `launchctl bootstrap` can return exit 1 even when the load completes successfully ~1-3s later. v0.1.1+ handles this transparently: `start.sh` ignores the bootstrap exit code and polls `launchctl print` for up to 10s to confirm the actual load state. A successful install hides the EIO entirely.

If you see `ERROR: failed to load after 10s: <label>` from `setup.sh` instead, it's a real failure (not the Sonoma quirk). The diagnostic surfaces the captured `launchctl bootstrap` stderr — read that first. If still unclear:

```bash
launchctl print "gui/$(id -u)/com.vreader.webdav"
launchctl print "gui/$(id -u)/com.vreader.icloud-sync"
```

and check Console.app for the `com.vreader.*` labels — Sonoma logs the real reason (malformed plist, bad path, permission issue) there.

#### iCloud Drive evicted local copies of `VReaderBackups/`

By design, iCloud Drive may evict the local copy of files in `~/Library/Mobile Documents/…` to save disk. To force-evict (or to verify what's evicted):

```bash
brctl evict ~/Library/Mobile\ Documents/com~apple~CloudDocs/VReaderBackups
```

The hourly sync re-uploads any files that were evicted before the next run, so an evicted local copy is not a data-loss event — only a cold-cache situation. The authoritative copy of your data is `~/vreader-webdav-data/` on disk.

#### Tailscale section in `status.sh` says "no current identity"

You haven't run `tailscale up` on this Mac yet. This recipe deliberately doesn't do that for you. Run it once, sign in, then `./scripts/status.sh` will print the Mac's MagicDNS name.

## Versioning

`VERSION` holds the bare semver. Every PR ends with a `chore: bump version to X.Y.Z` commit. The post-merge tag (`vX.Y.Z`) is cut from the squashed commit on `main`. See `.claude/rules/40-version-bump.md`.
