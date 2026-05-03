# 24 - README Sync

`README.md` is a checked-in claim about how this recipe works. Every PR that changes the install flow, scripts, network posture, or security posture must check whether the README's claims still hold and update them in the same PR if not.

This repo has no `docs/architecture.md`. The README is the only doc — it carries the architecture summary, file layout, operations, and security posture in a single page. Drift in the README is the only kind of drift possible here, and it's fully on the PR author to prevent.

## When to update `README.md`

Update in the same PR whenever:

| Trigger                                           | What to update                                               |
| ------------------------------------------------- | ------------------------------------------------------------ |
| New script in `scripts/`                          | File layout section + Operations section (one-liner per script) |
| New launchd plist (or removed plist)              | Architecture section + File layout                           |
| New `setup.sh` flag or environment variable       | Quick-start or Operations section, depending on user-facing-ness |
| Change to security / network posture (e.g. TLS, public ingress, new auth scheme) | Security posture section — this is load-bearing, drift here is dangerous |
| Change to where state lives (`$CONFIG_DIR`, data dir, iCloud path) | Architecture + File layout                  |
| New external dependency (e.g. swap rclone for something else) | Quick-start prerequisites + Architecture                |
| New troubleshooting case observed in the wild     | Troubleshooting section                                      |
| Existing stated fact becomes wrong                | Fix it. Stale-but-passing doc text is worse than no doc text |

You don't need to update for: comment-only edits, internal refactors of a script's body that don't change its CLI, formatting cleanups, or test-only changes.

## Pre-PR self-check

As the last step before opening a PR, run a quick mental audit:

1. **Diff scan.** What did this PR add/remove that the README mentions by name (a script path, a flag, a port, a launchd label, a config path)?
2. **Posture scan.** Did this PR touch anything that the Security posture section claims is true (no TLS, no public ingress, basic auth via htpasswd, gitleaks CI)? If yes, update or explicitly re-confirm.
3. **Layout scan.** If a file moved or a directory appeared, does the File layout block still match `ls`?

If a doc update is needed, it goes in the same PR as a separate commit
(`docs: update README for <change>`), not as a follow-up. The version bump tail
commit (per `40-version-bump.md`) lands after the doc update commit.

## Anti-patterns

- **"I'll update the README later."** Later doesn't happen. The doc rots and the next agent inherits stale claims.
- **Updating the README as the only commit in a separate PR.** Splits the change from its evidence; reviewers can't see what triggered the update.
- **Adding a new script without listing it in File layout + Operations.** A bare `scripts/whatever.sh` with no README mention is invisible to anyone reading the GitHub page.
- **Changing the security posture (e.g. enabling TLS) without rewriting the Security posture section.** The README is the contract for what this recipe is supposed to be safe for; silently changing the contract is the worst kind of drift.

## Rationale

README.md is the first thing humans read on the GitHub page, and the only documentation surface in the repo. If it lies about the security posture in particular, someone may deploy this on a network exposure they didn't intend. The cost of a one-line edit in the same PR is far below the cost of either kind of drift.
