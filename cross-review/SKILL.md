---
name: cross-review
description: "Get a finished code change reviewed by a model from another vendor (GLM 5.3 through opencode, else Mistral Vibe, else Codex), headless and read-only, running in the background while you do the slow remaining steps. Use when you have committed a change that is ready to ship and the repo expects review before a PR is marked ready or merged; also for a scoped re-review of fixes. Decides whether a review is worth running, when to launch it, and how to act on findings."
---

# Cross-vendor review

`scripts/cross-review` (on `PATH` as `cross-review`) freezes HEAD in a
throwaway worktree, sends the diff with the task brief to a reviewer from
another vendor, checks the JSON it returns, and prints ranked findings.
Because it reviews the frozen copy, you can keep working while it runs.

## 1. Decide whether to review

Review once per change, not per commit. Skip the review when the change is
only:
- docs, comments, copy or formatting;
- generated files, or a dependency bump whose CI lane proves it;
- under ~15 changed lines of plain logic, with a test that shows it works.

Always review, however small, a change that touches concurrency, persistence
or migrations, secrets or auth, parsing of untrusted input, process spawning,
trust boundaries or invariants the repo documents, or that deletes or weakens
a validation or a test assertion.

Above ~800 changed lines, review per commit range (`--since`) or split the
change first.

## 2. Launch at the right moment

Launch when the code is complete, committed, and the fast local tests pass,
and **before** the slow steps that follow: pushing and waiting for CI, remote
or device test lanes, e2e checks, benchmarks, the PR body, docs. The review
takes 5–20 minutes; those steps fill that time, so the review costs you
nothing extra. Launching at the very end doubles your wall time; launching
before tests pass wastes the review on code that is about to change.

1. Write the brief to a file (not in the repo) in 5–15 lines: the issue or
   task text, the constraints that apply, and what you claim the change
   does and how you verified it. Never paste your transcript.
2. Run it in the background (Bash `run_in_background: true`):

   ```bash
   cross-review --brief /path/to/brief.md
   ```

   Default range: merge-base with `origin/HEAD` to HEAD. `--base REF` changes
   it. `--effort low|medium|high` applies to Codex only: use `low` under ~100
   lines, `high` for the risk areas above.
3. Carry on with the slow steps. Don't wait, poll or sleep: the harness
   notifies you when it exits.
4. Do not mark the PR ready, merge, or report the work as done until the
   notification has arrived and you have acted on it. On repos where pushing
   to a ready PR restarts expensive CI, apply the fixes before marking ready.

## 3. Act on the result

Exit 0 prints the verdict and findings, most severe first. For each finding:

- Check it against the current code first (you may have committed since the
  reviewed SHA, which the summary prints). A finding you can't reproduce by
  reading the code is rejected, with the reason.
- Fix P0 and P1 findings, one at a time, testing each.
- Fix P2 and P3 when the fix is small and certain; otherwise note them in the
  PR body or open a follow-up issue.
- Put one line in the PR body: reviewer, number of findings, what you fixed,
  what you rejected and why.

Re-review only when a fix is itself non-trivial (over ~30 lines, or in a
risk area): `cross-review --since <reviewed-sha> --brief <brief-with-replies>`.
It reports P0/P1 only. One round; never loop.

## Gotchas

- **Exit 2 is not a pass.** Timeout, empty or invalid output means nobody
  reviewed the change. Say so in the PR; don't report it as clean. With
  `--vendor auto` the script already tried each reviewer that had headroom.
- **Exit 3 means no quota left** on any reviewer. Report it and ship
  without the review only if the repo allows that.
- **Uncommitted changes abort the run**, because the review pins HEAD.
  Commit first; a WIP commit is fine.
- **The vendor order is deliberate.** GLM first, because its 5-hour window
  has no weekly cap and idle headroom is lost; then Mistral Vibe
  (`mistral-medium-3.5`), whose monthly plan credits also expire unused;
  Codex last, because its weekly cap is the scarcest. `quota` can't read
  Vibe's credits, so a spent Vibe plan shows up as a failed run and Codex
  takes over. Don't override the order with `--vendor codex` to get a
  "better" review.
- **Don't widen the rubric.** Asking for style, design or test-coverage
  comments, or for a full fix per finding, raises false positives
  (`reference/sources.md`).
- Findings whose lines fall outside the diff's hunks are dropped into
  `findings.json` under `dropped_outside_diff`; read them only if one names a
  real break.
- Run directories live in `~/.cache/cross-review` (`CROSS_REVIEW_DIR`) and are
  pruned after 14 days. Each holds the prompt, raw events and stderr.

## Not possible

- No review of uncommitted work or of a PR you haven't checked out.
- No inline PR comments; the output is a summary for you to act on.
