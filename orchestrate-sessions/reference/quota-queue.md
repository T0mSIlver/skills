# Quota queue

Metered review quota (a Codex 5-hour window inside a weekly limit) is lost
when a window closes unused. `scripts/orch-queue <dir>` keeps it busy:

- Tasks are executables in `<dir>/pending/`, run in name order (`10-…`,
  `20-…`). Each writes its own result, for example to `<dir>/results/`.
- It reads the quota with `QUOTA_CMD` (default `orch-codexquota`), sleeps
  until a spent window reopens, and at weekly 100% spends a reset credit
  through `QUOTA_SPEND_CMD` (default `orch-codexquota --spend`, the credit
  that expires first).
- A task that fails because the limit hit mid-run goes back in the queue;
  any other failure moves it to `failed/`.
- It exits with `QUEUE EMPTY`. Run it with `run_in_background`, so the exit
  wakes you to add tasks.

`orch-codexquota` talks to `codex app-server` (`account/rateLimits/read`,
`account/rateLimitResetCredit/consume`); the Codex CLI has no command that
spends a credit.

## A task

```bash
#!/bin/bash
# 10-review-986: strongest-model review of PR #986 at its head.
cd /path/to/frozen/worktree-of-986 &&
  CROSS_REVIEW_CODEX_MODEL=<strongest-model> cross-review --vendor codex \
    --effort high --brief brief-986.md > ../results/pr986.txt 2>&1
```

Build the worktree inside the task, not when you queue it: the task may run
hours later, and the PR head may have moved.

## What to queue, in order

1. Reviews of the PRs labelled `waits:deep-review`, as they reach ready.
   Remove the label, with a comment, once the review ran and its P0 and P1
   findings are fixed or rejected with a reason.
2. Re-reviews after non-trivial fixes.
3. Read-only audits of main for one bug class, with a brief that names the
   invariants to check.

## Evidence

localvoxtral, 2026-09-28. The owner: "we're gonna be using the Codex 5-hour
limits as soon as they're available with Astra … The goal is to not waste
limits at all … and to finish the weekly limit". Reset credits come only
after the weekly limit, soonest-expiring first: two of the three were due to
expire within a week. The first runner lived in the session
scratchpad and hard-coded the repo path; this script replaces it.
