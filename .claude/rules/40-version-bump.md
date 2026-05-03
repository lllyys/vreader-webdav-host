# 40 - Version Bump Procedure

`vreader-webdav-host`'s version lives in a plain-text `VERSION` file at the repo root. There is no xcodegen / pbxproj / package manifest to keep in sync — `VERSION` is the single source of truth.

## When to bump

**Every PR must include a version bump.** The version line is owned by the PR
that ships the change, not by a separate release commit, so:

- **Bump before opening the PR** — bumping after the PR is open and rebasing
  conflicts with reviews.
- **Bump as the last step on the branch** — after the feature commits are in,
  not interleaved with them. A clean tail commit `chore: bump version to X.Y.Z`
  is easier to revert than a bump folded into a feature commit.
- **Choose increment by impact:**
  - `patch` — bug fix, docs, chores, refactors with no externally-visible change.
  - `minor` — new user-visible capability (new script, new `setup.sh` flag, new launchd job).
  - `major` — breaking change to install layout, CLI flags, or the network/auth posture.

The post-merge tag (`git tag v{version}` on the merge commit) is cut by the
finalizer once the PR lands on `main`.

## Files to update

| File      | Field                                       |
| --------- | ------------------------------------------- |
| `VERSION` | The full semver string (e.g. `0.2.0`), no leading `v`, no trailing whitespace beyond the file's terminating newline |

## Bump procedure

1. **Edit `VERSION`** — overwrite the contents with the new semver string. Keep the trailing newline.

2. **Verify**:

   ```bash
   cat VERSION
   ```

3. **Commit** (single commit, one file):

   ```bash
   git add VERSION
   git commit -m "chore: bump version to {version}"
   ```

4. **Push branch and open PR** as normal. The squash-merge commit on `main` carries the version forward.

5. **Tag and push** (only after the squashed commit lands on `main`):

   ```bash
   git checkout main
   git pull --ff-only origin main
   git tag v{version}
   git push origin v{version}
   ```

## Common mistakes

- Tagging before the squashed commit lands on `main` — orphan tag.
- Including a leading `v` in `VERSION` — the file holds the bare semver; the `v` prefix is only for the git tag.
- Bumping in a non-tail commit, then adding more feature commits afterward — makes reverts harder. Always bump last.

## Verification

After the tag pushes, `git describe --tags --exact-match HEAD` on `main` should print `v{version}`. The GitHub release page (if used) should reflect the same tag.
