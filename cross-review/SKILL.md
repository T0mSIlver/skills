---
name: cross-review
description: "Get a finished code change reviewed by a model from another vendor (GLM 5.3 through opencode, else Codex), headless and read-only, running in the background while you do the slow remaining steps. Use when you have committed a change that is ready to ship and the repo expects review before a PR is marked ready or merged; also for a follow-up review of fixes, which covers only the commits since the last review. Decides whether a review is worth running, when to launch it, and how to act on findings."
---

# Cross-vendor review

`cross-review` freezes HEAD in a throwaway worktree, sends the diff and your
brief to a reviewer from another vendor, and prints ranked findings. You can
keep working while it runs.

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

Above ~800 changed lines, review per commit range (`--since`) or split it.

## 2. Launch at the right moment

Launch once the code is committed and the fast local tests pass, **before**
the slow steps (CI, device lanes, e2e, benchmarks, the PR body, docs): the
review takes 5–20 minutes and they fill that time. Launching earlier reviews
code about to change; launching last doubles your wall time.

1. Write the brief to a file (not in the repo) in 5–15 lines: the issue or
   task text, the constraints that apply, and what you claim the change
   does and how you verified it. Never paste your transcript.
2. Run it in the background (Bash `run_in_background: true`):

   ```bash
   cross-review --brief /path/to/brief.md
   ```

   Default range: merge-base with `origin/HEAD` to HEAD (`--base REF`
   changes it). `--effort low|medium|high`: `low` under ~100 lines, `high` for
   the risk areas above.
3. Carry on with the slow steps. Don't wait, poll or sleep: the harness
   notifies you when it exits.
4. Do not mark the PR ready, merge, or report done until the notification
   has arrived and you have acted on it.

## 3. Act on the result

Exit 0 prints the verdict and findings, most severe first. For each finding:

- Check it against the current code first. A finding you can't reproduce by
  reading the code is rejected, with the reason.
- Fix P0 and P1 findings, one at a time, testing each.
- Fix P2 and P3 when the fix is small and certain; otherwise note them in the
  PR body or open a follow-up issue.
- Put one line in the PR body: reviewer, number of findings, what you fixed,
  what you rejected and why.

Review the fixes again only when a fix is non-trivial (over ~30 lines, or in
a risk area): rerun with a brief that replies to each finding. It reviews
only the commits since the last review, with the earlier findings; a HEAD
already reviewed returns that review. One follow-up round; never loop.

## 4. Grade the proof (before a PR merges without the owner)

`cross-review --proof <pr>`, from the PR's pushed head, reviews the whole PR,
grades its proof against owner-charter "Merged means checked" and posts or
edits one `<!-- proof-verdict -->` comment. A push makes it stale: rerun.
Rules: `reference/proof-verdict.md`.

## Gotchas

- **Exit 2 is not a pass.** Empty or invalid output, or a crash, means
  nobody reviewed the change. Say so in the PR; don't report it as clean.
  With `--vendor auto` the script already tried each reviewer that had
  headroom, and asked each once to fix an invalid answer.
- **Exit 4 means the reviewer hit `--timeout` (default 30 minutes)** and its
  work so far is printed. If that work is closing in on specific risks,
  `cross-review --continue RUN_DIR [--timeout SECONDS]` resumes it; if it is
  re-reading files or said nothing useful, report the review incomplete or
  rerun with another `--vendor`. Exit 4 is not a pass.
- **Exit 3 means no quota left** on any reviewer. Shipping unreviewed is
  Tom's call: post a card (ship now, or wait for the reset time `quota`
  prints).
- **Uncommitted changes abort the run**, because the review pins HEAD.
  Commit first; a WIP commit is fine.
- **The vendor order is deliberate:** GLM on the Z.ai plan, then Codex,
  whose weekly cap is the scarcest. Idle GLM headroom is lost. Don't force
  `--vendor codex` for a "better" review. Never review with `vibe`, even
  though it is installed: its plan is cancelled (`reference/vendors.md`).
- **Don't widen the rubric.** Asking for style, design or test-coverage
  comments, or for a full fix per finding, raises false positives
  (`reference/sources.md`).
- **A follow-up under 300 changed lines defaults to `--effort low`**: the
  reviewer's reading, not the diff, is what costs. Pass `--effort medium|high`
  when the new commits touch a risk area. `--full` only when they change what
  the earlier ones mean; `--since SHA` sets the start by hand.
- Findings whose lines fall outside the diff's hunks are dropped into
  `findings.json` under `dropped_outside_diff`; read them only if one names a
  real break.
- Run directories live in `~/.cache/cross-review` (`CROSS_REVIEW_DIR`) and are
  pruned after 14 days. Each holds the prompt, raw events and stderr.

## Not possible

- No review of uncommitted work or of a PR you haven't checked out.
- No inline PR comments; `--proof` posts its one verdict comment.
