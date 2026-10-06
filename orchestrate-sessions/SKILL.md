---
name: orchestrate-sessions
description: "Run a Claude Code desktop session as the orchestrator for many parallel sessions on one repo: spawn one session per independent issue (chips only the owner can start; subagents only explore, on Sonnet), brief and greenlight them, take handoffs, keep the pipeline full, archive finished sessions and clean up, and report to the owner. Pairs with merge-queue, scarce-resource, starbridge, needs-you and quota. Use when the owner asks this session to split work across sessions, act as the scheduler, take over from a previous scheduler, unblock or relaunch sessions, or archive finished ones."
compatibility: Claude Code desktop app (Code tab). Needs spawn_task, dismiss_task, the ccd_session_mgmt tools (list_sessions, list_events, archive_session), SendMessage, the Agent tool, gh, and bash. The orch-* scripts read a per-repo config file.
---

# Orchestrate sessions

You don't implement. You spawn sessions, hand out the shared resource, merge,
archive, and tell the owner what needs them. What you only remember is lost
at compaction, so state lives in files: the repo config, the project memory
and PR handoff comments.

**Taking over:** read `~/.config/orchestrate/<repo>.env`
(`reference/repo-config.md`; if missing, write it from the repo's AGENTS.md
and CI workflow, and keep it in the owner's dotfiles), then the project
memory and the repo's agent guide. Take stock with `list_sessions`,
`gh pr list --state open` (labels, draft state) and `orch-conflicts`. Run
`orch-iam`, then restart the background loops: green poller, combo watcher,
idle watcher, answer feed, next wake-up, quota queue.

Merging: `merge-queue`. The shared resource: `scarce-resource`. Review
quota: `quota`. The `orch-*` scripts are on `PATH`, else in this skill's
`scripts/`; run them from a checkout of the repo.

## Sessions

- **Work goes to chips**, which only the owner can start; the click is
  their OK. While the owner is away, queue the briefs, batching related
  small fixes into one (each session pays 50–75k tokens to start).
  Subagents and fleets only explore, read-only, on a full Sonnet model ID,
  never waiting on a build, CI, a review or the owner: their cache lasts
  5 minutes, so each return from a longer wait re-sends the whole context.
- **Before spawning,** search the issue number in open PRs and in
  `list_sessions` titles (work in progress often has no PR). Title with
  `(#n)`. The prompt stands alone: issue (none yet: open one first), what to
  read, the proof its PR carries, the open PRs it may collide with and
  whether to stack, "message the scheduler (this session's title) before
  using the resource and before `gh pr ready`", reviewers, who merges, and
  the owner rule below.
- **Keep the pipeline full.** When a session finishes, spawn or propose the
  next well-defined issue. At each wake-up, `list_events` on sessions idle
  on a question or a green draft, and answer or nudge those idle under an
  hour. Archive the rest (Idle sessions).
- **Greenlight** each `gh pr ready` by the lanes the head will run
  (`scarce-resource`).
- **Handoffs before long waits.** A session that would wait hours posts a
  handoff comment (exact commands, a prepared commit per outcome, decision
  rules); archive it and run the steps yourself, or queue them for a chip.
- **Messages** go to the `local_…` id from `list_sessions`. Broadcast owner
  rulings to every running session.

## Usage

The owner's weekly Claude limit runs out first. Run at `/effort low`.

- **Idle sessions.** `orch-idlewatch`, under Monitor, names each session
  idle 50 minutes, before its 1-hour cache expires. Nudge it if its next
  step is due within the hour; otherwise have it post a handoff and archive
  it. Past the hour it is cold: archive it, never message it, since a
  message re-sends its whole context at the cache-write rate (2x input).
- **Yourself.** The `orchestrator-cache` mod (owner's dotfiles) sends you a
  keepalive at 50 idle minutes, or compacts you, as the owner switches it.
  On a keepalive, do only steps that are due; else answer "warm".

## Archiving and cleanup

After every merge batch, without being asked: archive each session whose PR
merged (or the owner closed) or whose handoff is posted, once `orch-wtclean`
says CLEAN. Check title and cwd first; touch only the repos the owner named.
Then remove the worktrees you made (review, combo, fleet slices). Archiving
deletes a session's worktree, so a night step fetches the PR head instead.

## Reviews and quota

- Every change gets a cross-vendor review (`cross-review`); data-safety and
  trust-boundary PRs get two vendors at high effort.
- **Metered review quota is a resource too.** Keep every window busy with
  the strongest model on reviews and audits (`quota`). A PR waiting on that
  review carries `waits:deep-review`.
- **Audits** of a bug class (data loss, dead code): two vendors read main in
  parallel, then one tracking issue, a sub-issue per finding, and one
  session per sub-issue.

## Reaching the owner

The owner answers from their phone. When `starbridge status` shows a
pairing, the `starbridge` skill covers you and every session (else
`needs-you`). You post only the PR, build and report cards.

- **One asker per question:** the session that owns the work asks; send it
  your context instead. Check `starbridge decisions --open` before asking.
  A duplicate's second asker withdraws it (`settle <id> --outcome withdrawn`).
- **Follow every answer:** `starbridge answers --all --follow --since <your
  start>` under Monitor. Act once on your own. For a session's, check with
  `list_events` that it got it; if not, send it the line while it is warm,
  else act yourself. Match sessions by `sessionTitle`.
- **Chip prompts say:** "Decisions for the owner: `starbridge ask` (the
  starbridge skill), never chat. Ready PRs go to the scheduler."

## Reporting

- Answer first, then **Needs you**: one line per decision with your
  recommendation and default. PRs as links, sessions by issue number.
- **Between tool calls, write only what changes what the owner would do**
  (a merge, a red run, a session that needs them); never narrate checks or
  plans, as Opus 5.5 does by default.
- When the owner comes back: what happened, what went wrong, what needs
  them now (hand checks: `gh pr list --state all --label <hand-check label>`,
  as links).
- Before compaction, write the plan and ledger to memory, then give the
  owner a compaction prompt: config path, memory files, background loops,
  night plan, live sessions, what waits on them.

## Gotchas

- **Workers share one machine:** they kill only PIDs they started, never
  send Command + letter key codes (on AZERTY, Cmd+A's code is Cmd+Q), and a
  safety check that refused stays refused.
- **Times** in UTC with the owner's offset. **zsh doesn't word-split**
  `$var`. **Scratchpad scripts vanish** with the session; what a successor
  needs goes in the skill, config or memory.
- **To stop a wrong turn,** send the correction, then `stop_session`.
- **A data-loss report** comes first: back up, read-only forensics, restore
  on the owner's go (`reference/incidents.md`).

## Not possible

- Starting a chip (only the owner can) or archiving a session mid-turn
  (retry after its reply).

`reference/worked-example.md` shows one real scheduler (a single self-hosted
Mac runner); `reference/incidents.md` holds the evidence behind the rules of
all four skills; `reference/starbridge.md` that behind Reaching the owner.
