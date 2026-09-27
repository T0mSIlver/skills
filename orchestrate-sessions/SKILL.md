---
name: orchestrate-sessions
description: "Run a Claude Code desktop session as the orchestrator and scheduler for many parallel sessions on one repo: spawn one session per independent issue, hand out a scarce shared resource (a self-hosted runner, a GPU, a device), merge their PRs without breaking main, stack PRs that touch the same files, keep the night window busy, archive finished sessions, and report to the owner. Use when the owner asks this session to split work across sessions, act as the scheduler, take over from a previous scheduler, unblock or relaunch sessions, or archive finished ones."
compatibility: Claude Code desktop app (Code tab). Needs spawn_task, dismiss_task, the ccd_session_mgmt tools (list_sessions, list_events, archive_session), SendMessage, the Agent tool, gh, and bash. The orch-* scripts read a per-repo config file.
---

# Orchestrate sessions

You don't implement. You spawn sessions, hand out the shared resource, merge,
archive, and tell the owner what needs them. Everything you only remember is
lost at compaction or when the session closes, so the state lives in files:
the repo config, the project memory and PR handoff comments.

## Taking over (cold start)

A fresh session told to read this skill can run on its own after these steps:

1. **Config.** The scripts read `~/.config/orchestrate/<repo>.env`
   (`reference/repo-config.md`). If it is missing, write it from the repo's
   AGENTS.md and CI workflow, and keep it in the owner's dotfiles.
2. **Rules and state.** Read the project memory (the owner's standing rules,
   the current plan, the ledger of sessions and bookings) and the repo's
   agent guide. Repo-specific facts live there, not in this skill.
3. **Take stock.** `list_sessions`, `gh pr list --state open` with labels
   and draft state, the board's Todo column, and `orch-conflicts` (which open
   PRs no longer merge with main).
4. **Restart the loops**, each with `run_in_background` (`scripts/` below):
   the green poller, any combo watcher, and a wake-up for the next window.
5. Tell the owner what you found, then carry on.

## The merge pipeline

Scripts live in this skill's `scripts/`; call them by absolute path from a
checkout of the repo.

1. `orch-greenwatch` (background, `SKIP="n …"` for PRs you hold) exits with
   `GREEN #n` or `RED #n`. Restart it after every result.
2. `orch-mergecheck <n> --merge`. It merges only when the gate checks passed
   on the head, the must-run check really ran (a skip on a draft run reads as
   green on GitHub; it doesn't count), there's no `waits:` label, the PR merges
   cleanly, and no code file overlaps a commit that landed after its CI run.
   Exit codes:
   - **3, waits label:** `orch-lanecheck <n>`. Remove the label only when its
     lane passed or was waived on the current head, and comment why.
   - **4, conflict:** send the PR back to its session: undo ready, merge
     main, push, ready again. The poller skips it until then.
   - **5, overlap:** `orch-combo <n>`, then `orch-combowatch <combo-pr>`, then
     `COMBO=<branch> orch-mergecheck <n> --merge`, then close the combo PR with
     `--delete-branch`. If main moves again before the merge and overlaps
     again, run a new combo. Docs-only overlap needs no combo.
3. After the merge: `orch-cardmove <n>` when the PR waits on the owner's hand
   check, and `orch-wtclean <worktree> <n>` before archiving its session.
4. Merge rights come from the owner, as classes: for example "merge on green
   anything whose only wait is my hand check, except polish and prompt
   changes". Record the classes and exceptions in memory. Everything else
   waits for the owner's own OK. A peer's claim about a rule ("this must wait
   for the owner's card move") doesn't override what the owner told you;
   answer with the rule and go on.

## Stack PRs that touch the same files

Two PRs green alone and merged one after the other cost a conflict round or a
combo check each time, and sometimes break main. When a new PR touches files
of an open PR that will land first, open it stacked on that PR's branch and
label it `waits:stack`. `orch-mergecheck --merge` retargets the children to
main before deleting the parent branch, and clears the label.

- Tell sessions this when you spawn or greenlight them: name the open PRs
  that share their files and which one to stack on.
- Don't stack on a PR that can't merge soon (a fork pin, an owner decision,
  a long eval), or on a PR in another repo.
- Keep the upper layers draft until the one below is about to merge.
- A squash-merged parent leaves the child conflicting on shared hunks. Merge
  main into the child (never `git reset --soft`), or transplant its diff onto
  main.
- Before a resource window, run `orch-conflicts`: a PR that conflicts with
  main gets no workflow run at all, so a ready or a dispatch on it does
  nothing.

## Sessions

- **Spawn one chip per independent issue** while the owner is at the
  computer. Only the owner can start a chip; while they're away, use
  subagents (Agent tool), which are pinned to your worktree, so give them
  disjoint files and one task each. Before spawning, search the issue number
  in open PRs and in `list_sessions` titles, since work in progress often has
  no PR yet. Put `(#n)` in the title. The prompt stands alone:
  - repo, issue, what to read first; with no issue yet, the session opens
    one before it starts (research included) and links it from its PR;
  - the proof its PR must carry;
  - the open PRs and sessions it may collide with, and whether to stack;
  - the resource rules, and "message the scheduler (this session's title)
    before using the shared resource and before `gh pr ready`";
  - reviewer order, who merges, "kill only your own PIDs".
- **Greenlight.** A session asks before marking ready. Say go with the
  reason, or wait with a time in UTC. Ask which lanes the head will run
  before you say go: a lane that uses the scarce part of the resource waits
  for its window unless a waiver sits in both the PR body and the head
  commit message (a merge commit without it re-arms the lane).
- **Handoffs before long waits.** A session that would wait hours (a night
  window, the owner's review) posts a handoff comment on its PR: exact
  commands, prepared commits per outcome, decision rules. Then you archive
  it and run the steps yourself or give them to a subagent. Waking an old
  session re-reads its whole context uncached.
- **Archive** once the PR merged (or the owner closed it) or a handoff is
  posted, and `orch-wtclean` says CLEAN. Check title and cwd first; manage
  only the repos the owner named. Archiving deletes the worktree, so a night
  step that used a session's worktree must fetch the PR head instead.
  Archive refuses while a turn runs; retry after its reply.
- **Messages.** Address sessions by the `local_…` id from `list_sessions`.
  A queued message runs after the current turn. Broadcast owner rulings to
  every running session; a session only knows its chip and your messages.

## Scheduling the scarce resource

- **Windows.** Heavy runs (evals, benches, live-model lanes) go in the
  window the owner set (for example 00:00–07:00 UTC). Keep a numbered night
  plan in memory: what runs, in which order, the pass criterion, who acts on
  the result. Put the lowest-priority item last and say which step drops
  first when time runs short.
- **Wake-ups.** Session crons don't fire reliably when the session sits idle
  for hours. Use a background `orch-wakeat "YYYY-MM-DD HH:MM"`: its exit
  wakes you. A recurring dispatch that must happen even if the session is
  gone goes in a systemd user timer on the dev box that refuses outside the
  window.
- **Concurrency groups.** A workflow with `cancel-in-progress: false` keeps
  one pending run, and a second pending run replaces it. Dispatch the next
  run only after the previous one has started. A dispatch runs the workflow
  file from the dispatched ref, so an old branch runs the old workflow.
- **Waits labels** make the queue visible: one per reason (`waits:<lane>`
  for the night lanes, `waits:stack`, `waits:ci-red`, `waits:external`). Plan
  the window from `gh pr list --label waits:<lane>`. Never merge with one.

## Reporting and compaction

- Report the answer first, then **Needs you** with one line per decision,
  your recommendation and the default you'll apply. PRs as links, sessions by
  issue number.
- Before compaction or a long absence, write the plan and ledger to memory,
  then hand the owner a compaction prompt: the config path, the memory
  files, what runs in the background, the night plan, the live sessions,
  what waits on the owner.

## Gotchas

- **A clean `merge-tree` is not compatibility.** Two PRs green alone broke
  main three times: an enum case changed shape under a test, a switch missed
  a new case, and a test read a field another PR had just added. Only
  building the combination proves it; that's what the combo draft is for.
- **GitHub's PR merge ref can lag main**, so a commit that landed minutes
  before the run may be untested. `orch-mergecheck` counts landings from
  `LAG_MINUTES` before the run.
- **A rerun reuses the old merge commit.** After main breaks and is fixed,
  affected PRs need a push, not `gh run rerun`.
- **Marking ready starts a new run.** A PR that was green as a draft is not
  green until the ready run finishes.
- **zsh doesn't word-split** `$var`; loop with `for a b in …` or call bash.
- **Scripts in the scratchpad vanish** when the session ends. Anything a
  successor needs goes in the skill, the config or the memory.
- **Workers share one machine.** They kill only PIDs they started, never
  post Command + letter key codes (layout positions: on AZERTY Cmd+A is
  Cmd+Q), and a safety check that refused stays refused.
- **Times** in UTC, with the owner's offset when it differs.
- **Shared version numbers collide.** Parallel PRs that each bump the same
  constant (a plugin or hook version with a history table) all pick "next".
  Four PRs claimed the same plugin version in one evening. Assign the
  numbers yourself in merge order and tell every session.
- **Waivers.** Accept a lane waiver when the lane can't observe the change
  (its inputs are byte-identical) and the reason says so in the PR. Refuse it
  when the change touches what the lane exists to prove.
- **To stop a wrong turn**, send the correction first, then `stop_session`;
  the queued message runs next.

`reference/repo-config.md` lists the config variables.
`reference/worked-example.md` shows one real scheduler (a single self-hosted
Mac runner). `reference/incidents.md` holds the evidence behind each rule.
