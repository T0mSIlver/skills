# Worked example: one self-hosted Mac runner

T0mSIlver/localvoxtral, 2026-09-26. The owner's MacBook is the only
self-hosted runner and his daily machine. It runs every PR's `mac-lanes` job,
one at a time, so its queue is what every session waits for. The owner asked
one session to split the work across chips and then said: "keep this session
as the Mac scheduler". About 40 chips followed that day.

## The project's rules for the shared resource

From the repo's AGENTS.md ("Working an issue", "CI"):

- Claim an issue with `gh pr list --state open --search <n>` before starting
  and again before opening the PR.
- Open the PR as a draft. Mark it ready only once the hosted `build-test` is
  green; ready is what starts the Mac lanes.
- A push to a ready PR cancels its running Mac job and queues another, so
  `gh pr ready <n> --undo` before a series of pushes.
- No full-suite runs on the Mac, only filtered ones. No model inference on
  it: evals go to a LAN llama.cpp server or the dev box's GPU.

And the owner's session rule: message the scheduler before `gh pr ready`,
a UI Smoke dispatch or any Mac run.

## A chip prompt

```text
Repo: localvoxtral (T0mSIlver/localvoxtral). Build issue #641: agent term
proposals for projects on an enrolled remote host, the remote half of #609.
#609 merged today as PR #689; read its body and code first. Read
docs/agent/invariants.md, Sources/localvoxtral/ClaudeContext/AGENTS.md and
the external-tool-facts memory.

Proof: Linux unit tests; live `claude -p` and `vibe -p` runs on this box;
one short Mac slot for the macOS-host probe (ask the scheduler for it); the
herdr lane once when the PR goes ready.

Rules (the Mac scheduler is "CI speed optimizations"; message it):
- Claim check `gh pr list --state open --search 641`. Draft PR, `Closes #641`.
- No model inference on the Mac. Ask the scheduler before any Mac run,
  ready, try-pr or UI Smoke.
- Coordinate the plugin version with #672, which may bump it too.
- Review with cross-review (GLM first).
- Rebase onto main before ready. Kill only your own PIDs.
- The owner said merge on green: the scheduler merges.
```

## A go

```text
Scheduler: go for #692 now. build-test, linux and dogfood are green and no
other PR is on mac-lanes. Run `gh pr ready 692` and watch it with
`./scripts/watch-checks.sh 692` in the background, so you don't go idle
before it finishes. Don't push while mac-lanes runs. Tell me when it's
green or red. Avoid 20:00–20:45 UTC; the Mac is booked.
```

## Bookings, as reported to the owner

| Time (UTC) | What |
|---|---|
| 20:00–20:45 | #568's eval on main |
| about 20:45–21:30 | #568's CI job after it goes ready |
| 21:45–22:30 | #709's replay |
| 00:00 (02:00 Paris) | The owner's Nemotron bench |

**Card for the owner:** keep the Mac awake until the bench is done.

Each row after the first had a one-shot cron that woke the scheduler to
check the previous slot had ended and then send the next session its go.

## Queue order that worked

1. CI and lane-filter PRs first: each one cut Mac minutes for every later PR.
2. Test-only moves off the Mac next (merge on green, no hand check).
3. Features last, one Mac run each, on the final diff after review fixes.
4. A PR whose session wants several filtered Mac runs to iterate gets one,
   then pushes a draft and lets the hosted runner cover the rest.
