# quota-queue

`quota-queue <dir>` keeps Codex's 5-hour windows busy with deep reviews and
audits on the strongest model.

- Tasks are executables in `<dir>/pending/`, run in name order (`10-…`,
  `20-…`). Each writes its own result, for example to `<dir>/results/`.
  A task that exits 0 moves to `done/`, any other to `failed/`.
- A task that fails while the window or the weekly limit reads 100%, or
  while the quota can't be read, goes back in the queue, twice at most, so a task that fails for its own reason
  can't loop.
- After a credit spend that printed anything but `reset`, it waits an hour
  before trying again.
- The log is `<dir>/queue.log`, one UTC-stamped line per decision.
- `QUOTA_CMD` and `QUOTA_SPEND_CMD` swap in another metered provider; they
  default to `codex-limits` and `codex-limits --spend`. `QUOTA_CMD=none`
  runs the tasks back to back.

## A task

```bash
#!/bin/bash
# 10-review-986: strongest-model review of PR #986 at its head.
wt=/path/to/scratch/pr986
git -C /path/to/repo fetch -q origin pull/986/head &&
  git -C /path/to/repo worktree add --detach "$wt" FETCH_HEAD &&
  cd "$wt" &&
  CROSS_REVIEW_CODEX_MODEL=gpt-6-astra cross-review --vendor codex \
    --effort high --brief /path/to/brief-986.md > /path/to/results/pr986.txt 2>&1
```

An audit reviews no diff, so it runs `codex exec` directly. Feed the prompt
from a file: under a harness stdin never closes, and `codex exec` waits on it
forever at 0% CPU otherwise.

```bash
#!/bin/bash
# 30-audit-locking: read-only audit of main for one bug class.
cd /path/to/scratch/main-checkout && git pull -q --ff-only &&
  codex exec -C "$PWD" -m gpt-6-astra -c model_reasoning_effort='"high"' \
    -s read-only -o /path/to/results/audit-locking.md \
    - < /path/to/brief-locking.md > /dev/null
```

## What to queue, in order

1. Reviews of PRs waiting on a strongest-model review (orchestrate-sessions
   labels them `waits:deep-review`), as they reach ready.
2. Re-reviews after non-trivial fixes.
3. Read-only audits of main for one bug class, with a brief that names the
   invariants to check.
