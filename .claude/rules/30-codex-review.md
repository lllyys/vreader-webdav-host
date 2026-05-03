# 30 - Codex Review per PR

Every PR opened against this repo must pass an independent Codex review before `gh pr create`. Codex catches things Claude misses (and vice versa) — the v0.1.1 PR's mini-audit surfaced four issues including two Medium-severity correctness gaps (`launchctl print` proves load not health, bootout-leaves-stale-job risk). Skipping the review is how those would have shipped.

This rule binds the *agent opening the PR*, not the maintainer reviewing it after. The maintainer can still merge without re-running Codex.

## When to run

Always, on any PR. Specifically:

- Before `gh pr create` — never after, since findings should reshape the PR not chase it.
- **Sequence with the version bump:** review the substantive diff before the `chore: bump version` tail commit, apply any findings as additional commits, *then* add the bump as the last commit on the branch (per `40-version-bump.md`). Adding the bump-only commit after the review does not require a re-run, since the bump touches only `VERSION`. A rebase or base-branch update that changes the effective diff *does* require a re-run.
- On every iteration: if the PR is updated post-review with substantive changes (anything beyond typo / comment fixes, a `VERSION`-only bump, or commits applying findings from a prior round), re-run Codex on the new diff and replace the original disposition table. Commits that apply prior findings are the *intended* outcome of the previous round and don't restart the audit from scratch — they trigger a verification round (see *Disposition rules* below for what each severity requires after verification).

### Special case — rule-modifying PRs

A PR that modifies *this rule* (or any other Codex-review mechanics) is reviewing its own contract. To avoid the circular "the rule said skip the audit, so we skipped it" failure mode:

- The Codex audit on a rule-modifying PR runs on the *final* rule text (after any earlier-iteration fixes), not on a stale draft.
- The PR body must explicitly acknowledge that the rule itself was in scope of the audit (one line is enough — e.g. "self-referential audit: scope included `30-codex-review.md`").
- The human maintainer remains the final authority on whether a rule change ships. Codex's role here is to surface ambiguity / contradictions, not to ratify policy.

## How to run

Preferred entry point:

```
/codex-toolkit:audit-fix --mini scope: <branch-name>. context: <one-paragraph what changed and why>. focus the review on: <pointers to risky areas, e.g. shell-quoting, race conditions, fallback semantics>.
```

`audit-fix` drives the full audit → fix → verify loop (Codex finds issues, the agent or Codex applies fixes, Codex verifies in the same thread, repeats up to 3 rounds until the verdict is PASS). Use it instead of plain `audit`, which only reports findings — `audit` leaves the loop on the agent and is easy to short-circuit by skipping the fix step.

The `--mini` audit (5 dimensions: logic, duplication, dead code, refactoring debt, shortcuts) is the right scope for most patch-sized PRs in this repo. Use `--full` (9 dimensions) only if the change touches security/network posture or a brand-new launchd job.

If the slash command isn't available in the session, fall back to driving the loop manually with the codex MCP:

1. Audit pass — `mcp__plugin_codex-toolkit_codex__codex` with `sandbox=read-only`, `approval-policy=never`, prompt = full file contents + targeted review questions. Save the returned `threadId`.
2. Apply fixes — agent edits files directly (or sends fix prompts to Codex via `codex-reply` with `sandbox=workspace-write`).
3. Verify pass — `codex-reply` against the same `threadId` asking Codex to re-check each finding (FIXED / PARTIAL / NOT FIXED / REGRESSED).
4. Repeat steps 2-3 up to 3 rounds. Stop when verdict is PASS or only Lows that don't materially affect enforceability remain.

## Disposition rules

Every Codex finding gets a row in the PR body's "Codex review" table:

- **High** — must be fixed before opening the PR. No exceptions. No waiver, no deferral, no "ship it now and follow up."
- **Medium** — fixed by default; allowed to be explicitly *waived* only if the agent can articulate why the finding is not applicable in this PR's context (e.g. "Waived — covered by status.sh's PROPFIND probe in the same flow"). A waiver is not a deferral: if the finding is genuinely valid, fix it in this PR — do not defer it via a follow-up issue. The waiver text is read by the maintainer, not auto-accepted.
- **Low** — fix in the same PR if cheap. Otherwise, *defer* by opening a follow-up issue and reference it in the disposition (`Deferred — issue #<n>`). Silent skips are not allowed.

Always include the Codex thread ID in the PR body. Future review can `/codex-toolkit:continue <threadId>` the same thread to drill deeper or verify a fix without re-loading context.

## PR body format

The Codex review section in the PR body should look like:

```markdown
## Codex review

Sent the diff to Codex (mini audit) before opening this PR. {N} findings:

| Codex finding | Severity | Action taken |
|---|---|---|
| <one-line summary, file:line> | High | `Applied fix in <commit-or-line>` (no other option permitted) |
| <one-line summary, file:line> | Medium | `Applied fix in <commit-or-line>` OR `Waived — <why finding does not apply in this PR's context>` |
| <one-line summary, file:line> | Low | `Applied fix in <commit-or-line>` OR `Deferred — issue #<n>` |

Thread ID: `<threadId>`.
```

If Codex returns zero findings, still include a one-line note: `Codex review: 0 findings (thread <threadId>)`. The presence of the line is the audit trail.

## Anti-patterns

- **"I'll send to Codex after I open the PR."** Defeats the purpose. The PR is the PR; rebasing in Codex-driven changes after review starts is churn.
- **Generic prompts.** Sending "review this branch" to Codex without focus pointers gets shallow output. The audit prompt should specify which dimensions to weight, what the change is meant to fix, and where the risky areas are.
- **Ignoring Medium findings without comment.** Either fix them or explicitly waive in the PR body. Silent skips defeat the audit-trail value.
- **Re-running Codex on the same diff after each typo fix.** One review per substantive iteration. Typo / comment-only fixes don't count as new iterations.
- **Reusing a Codex result after a rebase or base-branch update.** If the rebase changed the effective diff (anything beyond a fast-forward of unrelated history), re-run the audit. A stale review attached to a different diff is worse than no review.
- **Omitting the Codex thread ID from the PR body.** Without it, the maintainer can't `/codex-toolkit:continue` the thread to drill into a finding or verify a fix. Treat the thread ID as a required field, same as the version-bump commit.

## Rationale

Two-model review is cheap insurance for a public infra recipe where bugs ship to anyone who clones the repo. Claude's blind spots (over-trusting shell exit codes, under-validating async handoffs to launchd) and Codex's blind spots (different from Claude's, but real) tend not to overlap. Five minutes of audit time has a higher expected value than five minutes of additional implementation polish at this stage.
