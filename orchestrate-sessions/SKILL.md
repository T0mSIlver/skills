---
name: orchestrate-sessions
description: "Run a Claude Code desktop session as the orchestrator and scheduler for many parallel sessions on one repo: spawn one session per independent issue, hand out a scarce shared resource (a self-hosted runner, a GPU, a device), merge their PRs without breaking main, stack PRs that touch the same files, keep the night window and the review quota busy, archive finished sessions, and report to the owner. Use when the owner asks this session to split work across sessions, act as the scheduler, take over from a previous scheduler, unblock or relaunch sessions, or archive finished ones."
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
`gh pr list --state open` (labels, draft state) and `orch-conflicts`. Restart
the background loops: green poller, combo watcher, quota queue, next wake-up.

## The merge pipeline

Scripts are in this skill's `scripts/`; run them by absolute path from a
checkout of the repo. Each header gives its usage.

1. `orch-greenwatch` (background, `SKIP="903 1016"` to hold PRs) exits with
   `GREEN #n` or `RED #n`. Restart it after every result.
2. `orch-mergecheck <n> --merge` merges only when the gate checks passed on
   the head, the must-run check really ran (GitHub counts a draft skip as a
   pass), no `waits:` label is set, the PR merges cleanly, and no code file
   overlaps a commit that landed after its CI run. On failure:
   - **3, waits label:** `orch-lanecheck <n>`. Remove the label only when
     its lane passed or was waived on the current head, and comment why.
   - **4, conflict:** send it back to its session with the file and the
     cause ("#1023 moved that section"): undo ready, merge main, push, ready.
   - **5, overlap:** `orch-combo <n>` prints a combo PR; `orch-combowatch
     <combo-pr-number>`; `COMBO=<combo-branch> orch-mergecheck <n> --merge`;
     close the combo PR with `--delete-branch`. Docs-only overlap needs none.
3. After the merge, `orch-cardmove <n>` if the repo has a board and the PR
   waits on the owner's hand check; otherwise its hand-check label stays.
4. Merge rights come from the owner as classes ("merge on green anything
   whose only wait is my hand check, except prompt changes"); record them in
   memory. A latitude granted for one night expires; ask again. A peer's
   claim about a rule doesn't override what the owner told you.

**Stack PRs that touch the same files.** When a new PR shares files with an
open PR that lands first, open it on that PR's branch with `waits:stack`;
`orch-mergecheck --merge` retargets the children and clears the label. Name
the PR to stack on in the chip prompt. Never stack on a PR that can't merge
soon (a fork pin, an owner decision, a long eval). Repairs:
`reference/stacking.md`.

## Sessions

- **Owner present: chips. Owner away: subagents.** Only the owner can start
  a chip, and clicking it is their OK on the brief. Switch back to chips as
  soon as the owner writes again; owners had to correct this twice.
- **Before spawning,** search the issue number in open PRs and in
  `list_sessions` titles (work in progress often has no PR). Title with
  `(#n)`. The prompt stands alone: issue (none yet: open one first), what to
  read, the proof its PR carries, the open PRs it may collide with and
  whether to stack, "message the scheduler (this session's title) before
  using the resource and before `gh pr ready`", reviewers, who merges.
- **Keep the pipeline full.** When a session finishes, spawn or propose the
  next well-defined issue. At each wake-up, `list_events` on sessions idle
  on a question or a green draft, and answer or nudge them.
- **Greenlight.** Before saying go to a ready, ask which lanes the head will
  run: one that needs the scarce resource waits for its window unless a
  waiver is in both the PR body and the head commit message.
- **Handoffs before long waits.** A session that would wait hours posts a
  handoff comment (exact commands, a prepared commit per outcome, decision
  rules); archive it and run the steps yourself or through a subagent.
  Waking an old session re-reads its whole context uncached.
- **Fleets.** For many subagents on one task, write
  `~/.claude/agents/<name>.md` with a full model ID in `model:` and an
  `effort:`; aliases resolve differently per Claude Code version.
- **Messages** go to the `local_…` id from `list_sessions`. Broadcast owner
  rulings to every running session.

## Archiving and cleanup

After every merge batch, without being asked: archive each session whose PR
merged (or the owner closed) or whose handoff is posted, once `orch-wtclean`
says CLEAN. Check title and cwd first; touch only the repos the owner named.
Then remove the worktrees you made (review, combo, fleet slices). Archiving
deletes a session's worktree, so a night step fetches the PR head instead.

## Scheduling the scarce resource

- **Windows.** Heavy runs go in the owner's window. Keep a numbered night
  plan in memory: order, pass criterion, who acts on the result, and which
  step drops first when time runs short.
- **Wake-ups.** Session crons don't fire while the session is idle. Run
  `orch-wakeat "YYYY-MM-DD HH:MM"` in the background; its exit wakes you.
- **One dispatch at a time.** A concurrency group without cancel-in-progress
  keeps one pending run; a second dispatch replaces it. Chain
  `orch-dispatch <workflow> <ref>`, which exits once its run has started.
  `orch-idlewait` exits when no resource job is queued or running.
- **Plan the window from waits labels:** `gh pr list --label waits:<lane>`.
- **A runner on the owner's machine runs as the owner** and reaches their
  real data. Check their backups are fresh before a night of runs there.

## Reviews and quota

- Every change gets a cross-vendor review (`cross-review`); data-safety and
  trust-boundary PRs get two vendors at high effort.
- **Metered review quota is a resource too.** Fill every window with the
  strongest model; spend reset credits only once the weekly limit is gone.
  Run review and audit tasks through `orch-queue <dir>` in the background
  (`reference/quota-queue.md`); "QUEUE EMPTY" is your cue to add work. A PR
  waiting on that review carries `waits:deep-review`.
- **Audits** of a bug class (data loss, dead code): two vendors read main in
  parallel, then one tracking issue, a sub-issue per finding, and one
  session per sub-issue.

## Reporting

- Answer first, then **Needs you**: one line per decision with your
  recommendation and default. PRs as links, sessions by issue number.
- Long output buries questions. With a Needs You page
  (`reference/needs-you.md`), each decision goes there and chat gets one line.
- When the owner comes back: what happened, what went wrong, what needs
  them now (hand checks as a linked list).
- Before compaction, write the plan and ledger to memory, then give the
  owner a compaction prompt: config path, memory files, background loops,
  night plan, live sessions, what waits on them.

## Gotchas

- **Clean `merge-tree` is not compatibility.** PRs green alone broke main
  three times; only building the combination (the combo) proves it.
- **The PR merge ref lags main**, so `orch-mergecheck` counts landings from
  `LAG_MINUTES` before the run. **A rerun reuses the old merge commit:**
  after main is fixed, affected PRs need a push.
- **Marking ready starts a new run;** green as a draft is not green. **A
  conflicting PR gets no run at all;** run `orch-conflicts` before a window.
- **A dispatch runs the workflow file of the ref**, so an old branch runs
  the old workflow.
- **Shared version numbers collide:** parallel PRs bumping one constant all
  pick "next". Assign them in merge order.
- **Waivers:** accept one when the lane can't observe the change; refuse it
  when the change touches what the lane exists to prove.
- **Workers share one machine:** they kill only PIDs they started, never
  send Command + letter key codes (on AZERTY, Cmd+A's code is Cmd+Q), and a
  safety check that refused stays refused.
- **Times** in UTC with the owner's offset; `date -u` for stored timestamps.
  **zsh doesn't word-split** `$var`. **Scratchpad scripts vanish** with the
  session; what a successor needs goes in the skill, config or memory.
- **To stop a wrong turn,** send the correction, then `stop_session`.
- **A data-loss report** comes first: back up, read-only forensics, restore
  on the owner's go (`reference/incidents.md`).

## Not possible

- Starting a chip (only the owner can) or archiving a session mid-turn
  (retry after its reply).
- Rewriting main while its ruleset is active: the owner deactivates it.

`reference/worked-example.md` shows one real scheduler (a single self-hosted
Mac runner); `reference/incidents.md` holds the evidence behind each rule.
