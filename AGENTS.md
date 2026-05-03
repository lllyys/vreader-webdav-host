# [AGENTS.md](http://AGENTS.md)

Shared instructions for all AI agents (Claude, Codex, etc.) working on `vreader-webdav-host`.

This is a one-deployment-per-Mac infra recipe: shell scripts + launchd plists that bootstrap an `rclone serve webdav` server backing the iOS app [vreader](https://github.com/lllyys/vreader). It is not an application codebase. Keep it small.

## Working agreement

- Run `git status -sb` at session start.
- Read relevant files before editing — especially `setup.sh` and the launchd templates, since their substitution contract is load-bearing.
- Keep diffs focused; no drive-by refactors.
- Do not commit unless explicitly requested.
- **Do not put real values in the repo.** Hostnames, paths, htpasswd hashes, and Tailscale auth keys are per-deployment — they live in `~/.config/vreader-webdav-host/` outside the repo. Templates use `${PLACEHOLDER}`; examples use a `REPLACE_ME` sentinel.
- **Do not embed Tailscale auth keys, and do not invoke ********`tailscale up`******** from any script.** The repo only reads Tailscale state (in `scripts/status.sh`); it never authenticates or modifies the tailnet.
- **Do not skip the gitleaks workflow or the ********`setup.sh`******** sentinel-fail check.** Both are non-negotiable per the security posture documented in README.md.
- **Version bump per PR**: every PR ends with a `chore: bump version to X.Y.Z` commit on the branch — patch for fixes/docs/chores, minor for new capabilities, major for breaking changes. Tag is cut from the merge commit on `main` post-merge. See `.claude/rules/40-version-bump.md`.
- **Docs sync per PR**: when a PR adds a new script in `scripts/`, a new launchd plist, a new `setup.sh` flag, or changes the security/network posture, update `README.md` in the same PR (separate commit before the version bump). Triggers + checklist in `.claude/rules/24-doc-sync.md`.
- **Issue tracking**: use GitHub Issues for bugs, features, and tasks. This repo is small enough that a separate `docs/bugs.md` / `docs/features.md` / `docs/tasks.md` workflow would be overhead. Reference issues from PRs as `Refs #N` (or `Fixes #N` for small single-issue fixes).

## Local verification

There's no test harness — verification is end-to-end on a real Mac:

1. Sandbox sentinel: see the snippet in README's Troubleshooting and the acceptance criteria in commit history. It asserts `setup.sh` exits 1 with the sentinel error when `REPLACE_ME_PLACEHOLDER` is present in `~/.config/vreader-webdav-host/htpasswd`.
2. Plist sanity: after `setup.sh`, run `plutil -lint "$HOME/.config/vreader-webdav-host"/*.plist` and grep for any leftover `REPLACE_ME` or `${...}` — both should be empty.
3. Status: `scripts/status.sh` should show `loaded` for both jobs, HTTP 401 from the PROPFIND probe, and (if Tailscale is up) the node's MagicDNS name.

## Auth for AI tooling

Prefer subscription auth (Claude Max, ChatGPT Plus/Pro, Google account) over API keys for sustained sessions — same reasoning as in vreader's AGENTS.md.
