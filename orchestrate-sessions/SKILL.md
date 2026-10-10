---
name: orchestrate-sessions
description: "Run a Claude Code desktop session as the orchestrator for many parallel sessions on one repo: spawn one session per independent issue (chips only the owner can start; subagents only explore, on Sonnet or Haiku), brief and greenlight them, take handoffs, keep the pipeline full, archive finished sessions and clean up, and reach the owner through Starbridge cards. Pairs with merge-queue, scarce-resource, quota and starbridge. Use when the owner asks this session to split work across sessions, act as the orchestrator, take over from a previous one, unblock or relaunch sessions, or archive finished ones."
compatibility: Claude Code desktop app (Code tab). Needs the starbridge CLI, spawn_task, dismiss_task, the ccd_session_mgmt tools (list_sessions, list_events, archive_session), SendMessage, the Agent tool, gh, and bash. The orch-* scripts read a per-repo config file.
---

# Orchestrate sessions

You don't implement. You spawn sessions, hand out the shared resource, merge,
archive, and bring the owner what needs them. What you only remember is lost
at compaction, so state lives in files: the repo config, the project memory
and PR handoff comments.

**Taking over:** read `~/.config/orchestrate/<repo>.env`
(`reference/repo-config.md`; if missing, write it from the repo's AGENTS.md
and CI workflow, and keep it in the owner's dotfiles), then the project
memory and the repo's agent guide. Take stock with `list_sessions`,
`gh pr list --state open`, `orch-conflicts` and `starbridge decisions
--open`. Run `orch-iam`, then restart the background loops: green poller,
combo watcher, idle watcher, next wake-up, quota queue.

The other skills: `merge-queue` (merging), `scarce-resource` (the shared
runner or GPU), `quota` (review windows), `starbridge` (writing cards). The
`orch-*` scripts are on `PATH`, else in this skill's `scripts/`.

## Sessions

- **Work goes to chips**, which only the owner can start. Batch related
  small fixes into one (each session pays 50–75k tokens to start). You
  can't tell whether the owner is at the desktop, so post each brief as a
  comment on its issue, spawn the chip, and post one card per batch with a
  one-line Remote Control prompt per session (`Work #n in ~/work/<repo>:
  the brief is the issue's last comment`). When one starts, dismiss the
  chip or withdraw the card.
- **Subagents** only explore, read-only, on Sonnet or Haiku, never waiting
  on a build, CI, a review or the owner (their cache lasts 5 minutes).
- **Before spawning,** search the issue number in open PRs and
  `list_sessions` titles. Title with `(#n)`. The brief stands alone: issue,
  what to read, the proof its PR carries, PRs it may collide with, "message
  the orchestrator (`<your local_… id>`) before using the resource and
  before `gh pr ready`" (you greenlight by lanes, `scarce-resource`), who
  merges. A brief never overrides the owner's CLAUDE.md (reviews go
  through `cross-review`, subagents run on Sonnet or Haiku).
- **Keep the pipeline full.** When a session finishes, spawn the next
  well-defined issue. At each wake-up, `list_events` on sessions idle on a
  question or a green draft; nudge those idle under an hour.
- **Handoffs before long waits.** A session that would wait hours posts a
  handoff comment (exact commands, a prepared commit per outcome, decision
  rules); archive it and run the steps yourself, or queue them for a chip.
- **Messages** go to the `local_…` id from `list_sessions`. Workers write
  in the shapes of the owner's CLAUDE.md ("When an orchestrator runs you").

## Starbridge

Each card's answer goes back only to the session that asked.

- **One asker.** The session that owns the work posts its card. You post
  only what spans sessions: merge order, scope across PRs, quota, pipeline
  policy. For a session's work, send it the context and let it ask.
  Before posting, read `starbridge decisions --open`; never ask the same
  thing twice, and never also in chat.
- **Answers.** Workers send `d_… answered: <choice>. Doing: <next>.` on
  every answer. At each wake-up, `starbridge answers --all --since <last
  read>` (the time lives in the project memory) catches the rest: relay
  each to its session while warm, else act on it. Never poll, Monitor the
  feed or `wait` on another session's card.
- **Answered elsewhere.** When the owner answers a worker's card in your
  chat, relay it; the worker withdraws the card.
- **Rulings** wider than one PR: broadcast to running sessions, write to
  memory.
- **Before archiving** a session, withdraw its open cards with a reason.
- **Relay "Tom answered" or "Tom was asked" only with the card id.**

## Usage

The owner's weekly Claude limit runs out first. Run at `/effort low`.

- **Idle sessions.** `orch-idlewatch`, under Monitor, names each session
  idle 50 minutes. Nudge it if its next step is due within the hour, else
  have it post a handoff and archive it. Past the hour, archive it and
  never message it: a message re-sends its whole context at the
  cache-write rate.

## Archiving and reviews

- After every merge batch, unasked: archive each session whose PR merged
  or closed or whose handoff is posted, once `orch-wtclean` says CLEAN.
  Check title and cwd first. Then remove the worktrees you made. Archiving
  deletes a session's worktree, so a night step fetches the PR head.
- Every change gets a cross-vendor review; data-safety and trust-boundary
  PRs get two vendors at high effort. Keep every review window busy
  (`quota`); a PR waiting on the strongest model carries
  `waits:deep-review`.

## Reporting

- Answer first. Each decision is its own card with your recommendation;
  chat names the open card ids, not the questions.
- **Between tool calls, write only what changes what the owner would do**
  (a merge, a red run, a session that needs them). Opus 5.5 writes a
  progress note there by default.
- Before compaction, write the plan and ledger to memory, then give the
  owner a compaction prompt: config path, memory files, background loops,
  live sessions, open card ids, what waits on them.

## Gotchas

- **Workers share one machine:** they kill only PIDs they started, never
  send Command + letter key codes (on AZERTY, Cmd+A's code is Cmd+Q), and a
  safety check that refused stays refused.
- **Times** in UTC with the owner's offset. **zsh doesn't word-split**
  `$var`. **Scratchpad scripts vanish** with the session.
- **To stop a wrong turn,** send the correction, then `stop_session`.
- **A data-loss report** comes first: back up, read-only forensics, restore
  on the owner's go (`reference/incidents.md`).

## Not possible

- Starting a chip (only the owner can), knowing whether the owner is at
  the desktop, or archiving a session mid-turn (retry after its reply).

`reference/starbridge.md` holds the incidents behind the Starbridge rules;
`reference/incidents.md` the rest; `reference/worked-example.md` one real
orchestrator.
