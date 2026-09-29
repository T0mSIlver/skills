---
name: quota
description: "Read the model usage windows with `quota` and decide which model spends which window: GLM 5.3 first, then Vibe, Codex last for per-change reviews; every Codex 5-hour window filled with the strongest model on queued review and audit tasks; Codex reset credits spent only once the weekly limit is gone. Use before launching a review, audit or delegated run, when choosing between GLM, Vibe and Codex, when a Codex window or weekly limit is spent, when deciding whether to spend a reset credit, and to keep Codex windows busy with a queue of tasks (`quota-queue`)."
compatibility: "`quota` reads CodexBar (`codexbar usage --format json`) and is installed from Tom's dotfiles, not by this skill. `codex-limits` and `quota-queue` need the codex CLI, python3, bash and flock."
---

# Quota

Run `quota` before you pick a reviewer, launch an audit or queue work. It
takes about 10 s and appends each reading to
`~/.local/state/quota/history.jsonl`.

```text
codex   5h    100%  1:20 AM
codex   week   43%  Oct 3 at 7:20 PM      11% in deficit | Expected 32% used | Runs out in 2d 23h
codex   reset credit available, expires 2026-10-04
zai     5h     21%  4:40 AM               5% in reserve | Expected 26% used | Lasts until reset
claude  week   85%  resets Sep 30, 10pm   12% in deficit | Expected 73% used | Runs out in 21h 43m
mistral api    93%  €23.76 / €25.50 · €1.74 left
mistral vibe   37%  €93.66 / €255.00 · €161.34 left
```

## What the rows mean

- The percentage is how much of that window is used. The next column says
  when it resets, in the machine's local time.
- **Pace** compares use with an even spend across the window. "5% in
  reserve" means that much is unused so far and is lost at reset unless
  something spends it. "11% in deficit" means use runs ahead of even pace,
  and "Runs out in" says when the window hits 100% at the current rate.
  On the Codex weekly row a deficit is what Tom wants, because he wants the
  weekly limit used up.
- **codex** has a 5-hour window inside a weekly limit. Each `reset credit`
  line is one credit and its expiry date. A credit is a full reset. It
  clears the weekly and the 5-hour window at once.
- **zai** is GLM 5.3 through opencode. It has a 5-hour window and no weekly
  cap, so headroom in one window is gone at the next.
- **mistral api** is the plan's included La Plateforme API allowance. Reviews
  don't spend it, so a high reading there says nothing about Vibe.
- **mistral vibe** is the Vibe plan credits, monthly (about €255), and the
  budget that GLM 5.3 through Vibe draws on. Both mistral rows reset on the
  1st.
- **claude** is Tom's Claude subscription, which this session and its
  subagents spend. It is not a reviewer. A weekly row near 100% means fewer or cheaper subagents
  (Sonnet), not a different reviewer.

## Who spends what

1. **Per-change reviews** (`cross-review`): GLM 5.3 through opencode, then
   GLM 5.3 through Vibe, then Codex (gpt-6-sol) only when both are spent or
   failed. GLM goes first because its window has no weekly cap; Vibe's
   credits are lost at month end if unused.
2. **A window about to reset with room left goes first.** A zai window with
   reserve and under an hour to go, Vibe credits in the last days of the
   month, or a Codex weekly limit resetting within a day. Spend that one
   before the usual order.
3. **Fill every Codex 5-hour window with the strongest model**
   (currently gpt-6-astra) on deep reviews and audits, through
   `quota-queue`. Room left when a window closes is lost. This is
   separate from step 1. Routine reviews don't wait for Codex, and deep
   reviews don't wait for GLM.
4. **Reset credits only once the weekly limit is at 100%**, the credit that
   expires first. At 5-hour 100% with weekly room, wait for the 5-hour
   reset, because a credit spent then clears a weekly limit that still had room.

## Helpers on PATH

- `codex-limits` prints `<5h-used-%> <weekly-used-%> <5h-resets-at-epoch>
  <credits>` in under a second, e.g. `100 43 1790637613 3`. Poll this,
  not `quota`.
- `codex-limits --spend` spends the credit that expires first and prints
  `reset`, `nothingToReset`, `noCredit` or `alreadyRedeemed`.
- `quota-queue <dir>` runs the executables in `<dir>/pending/` in name
  order while Codex has room, sleeps through a spent window, and spends a
  credit at weekly 100%. Run it with `run_in_background`; it exits with
  `QUEUE EMPTY`, which is your cue to add tasks. Task layout, what to queue
  and the log: [reference/queue.md](reference/queue.md).

## Gotchas

- **You tested `--spend`.** A spend cannot be undone and credits are
  scarce. Check with plain `codex-limits`; spend only under rule 4.
- **You looked for a Codex CLI command that spends a credit.** There is
  none. Only `codex app-server` (`account/rateLimitResetCredit/consume`)
  does, which is why `codex-limits` exists.
- **A queued task never ran.** `quota-queue` runs only files with the
  executable bit; `chmod +x` each task.
- **`another quota-queue runs on <dir>`.** One runner per directory holds
  a lock. Don't start a second; add tasks to `pending/` and the running one
  picks them up.
- **A task ran against a stale PR head.** Build the worktree inside the
  task, not when you queue it, because it may run hours later.
- **`codex-limits` printed `None`.** The account is logged out or the
  app-server changed its reply. `quota-queue` reads that as unreadable and
  retries every 5 minutes; tell Tom instead of spending.
- **A credit will expire before the weekly limit can run out.** Tom
  decides. Put it in a Needs you line with the expiry date. Don't spend
  it early.

## Not possible

- Resetting only the 5-hour window. Every credit clears both.
