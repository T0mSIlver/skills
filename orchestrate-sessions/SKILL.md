---
name: orchestrate-sessions
description: "Run a Claude Code desktop session as the orchestrator and scheduler for many parallel sessions on one repo: spawn one chip per independent issue, hand out slots on a scarce shared resource (a self-hosted runner, a GPU, a device), watch and steer sessions, merge their PRs without breaking main, archive finished sessions, and report to the owner. Use when the owner asks this session to split work across sessions, act as the scheduler, take other sessions under its umbrella, unblock or relaunch sessions, or archive finished ones."
compatibility: Claude Code desktop app (Code tab). Needs the spawn_task, dismiss_task and ccd_session_mgmt tools (list_sessions, list_events, send_message, stop_session, archive_session), CronCreate, and gh.
---

# Orchestrate sessions

You don't implement. You spawn sessions, hand out the shared resource, merge,
archive, and tell the owner what needs them. Keep a ledger in the project's
memory (per session: issue, PR, what it waits on; plus resource bookings) and
update it as things change. Compaction and overnight cache expiry wipe
anything you only remember.

## Happy path

1. **Take stock.** `list_sessions` (title, cwd, `isRunning`, `prNumber`,
   `prState`), `gh pr list --state open`, open issues.
2. **Spawn one chip per independent issue** with `spawn_task`. First search
   the issue number in both `gh pr list --state open --search <n>` and the
   `list_sessions` titles, because a session in progress often has no PR yet. Put
   `(#n)` in the title so later searches find it. The prompt must stand alone:
   - repo, issue number, what to read first (issue, AGENTS.md, named memory
     files, the PR it builds on);
   - the proof its PR must carry;
   - the in-flight sessions and PRs it may collide with, by issue number;
   - the resource rules, and "ask the scheduler (this session's title)
     before using the shared resource and before `gh pr ready`";
   - the reviewer order, who merges, "kill only your own PIDs".

   To change a chip, spawn the new one, then `dismiss_task` the old one.
3. **Schedule the shared resource.** Sessions ask; you answer "go" or "wait"
   with the reason. A go names the slot with a hard end time **in UTC**,
   what to do after (watch checks, report, merge or hand back), and whether
   the session may merge. Grant first to work that unblocks other work (CI
   fixes, speed-ups, lane opt-outs). Book long windows (an overnight eval) in
   the ledger and give no go that overlaps them. An idle session never wakes
   itself, so for a slot that starts later, set a one-shot `CronCreate` that
   wakes you to send its go.
4. **Watch.** Replies arrive as cross-session messages. For a session that
   went quiet, `list_events` (`limit` 3–8, page with `before_uuid`) shows its
   last turns. Nudge a session idle on a green draft: "where is it, what
   blocks you". Tell every worker to run its CI watcher with
   `run_in_background`, so it doesn't end its turn before reporting.
   Broadcast rule changes (reviewer switch, a new owner ruling) to every
   running session; a session knows only its chip and your messages.
5. **Merge** only what the owner delegated (below), after the pre-merge
   check.
6. **Archive** a session once it says "done, nothing left local" and its PR
   is merged or closed. Pass a reason (`PR #n merged, #m closed`).
7. **Report** to the owner: the answer first, then a **Needs you** block
   with one line per decision, your recommendation and the default you'll
   apply. Refer to sessions by issue number and PRs as links. Don't invent
   names for sessions, slots or steps.

## Pre-merge check

Run this before every merge, even when the PR is green:

```bash
git fetch -q origin main "+pull/$N/head:pr$N"   # "+": a force-pushed PR leaves a stale local ref otherwise
git merge-base --is-ancestor origin/main "pr$N" && echo BASE_CURRENT || echo BEHIND
```

When it's behind, the green run tested an old main. List what main changed
since the PR's base (`git diff --name-only $(git merge-base origin/main
pr$N) origin/main`). If any of it is a check, a filter, a shared type or a
file the PR touches, build the combined tree and run those checks on it:

```bash
T=$(git merge-tree --write-tree origin/main "pr$N") && C=$(git commit-tree "$T" -p origin/main -p "pr$N" -m combo)
git worktree add -q --detach "$SCRATCH/combo$N" "$C"   # run main's new checks here, then remove it
```

On a failure, don't merge. Send the session the failing output and have it
rebase, fix, and ask again.

## Gotchas

- **A clean `merge-tree` is not compatibility.** Two PRs green alone broke
  main twice in one afternoon: an enum case changed shape under a test that
  bound the old one, and a switch missed a new case. Another time, main's
  new completeness check failed on a PR whose run predated it. Only building
  and running the combination proves it.
- **A PR's CI rerun reuses its old merge commit.** After main breaks and is
  fixed, the affected PRs need a new push, not `gh run rerun`.
- **Merge rights are narrow.** Merge on green only the classes the owner
  named (for example CI, lane opt-outs, test-only moves, or "merge on green,
  I'll check later"). Everything else waits for the owner's own "LGTM". A
  session refuses an owner OK relayed by a peer, and it's right to. Ask the
  owner to answer in that session, or merge it yourself if the owner told
  you directly.
- **`gh pr merge --delete-branch` fails when a worktree holds the branch**,
  after the remote merge succeeded. Check `gh pr view N --json state`, then
  `git push origin --delete <branch>`.
- **Messaging.** `SendMessage` by title fails for sessions `ListAgents`
  doesn't list. `send_message` with the `session_id` from `list_sessions`
  reaches any local session. `delivery: queued` means a turn is running
  there; it runs after that turn, so don't wait on it. Start each message
  with "Scheduler:" so it doesn't read as the owner.
- **To stop a wrong turn**, `send_message` the correction first, then
  `stop_session`. The queued message runs next. A duplicate chip was stopped
  this way before it touched the shared GPU.
- **Times.** state every time in UTC and write the offset when the owner's
  clock differs ("20:00 UTC (22:00 Paris)"). A session read a bare "19:45"
  as local time and would have pulled a PR back to draft two hours early.
  `CronCreate` takes the box's local time, so run `date` and convert. Its jobs
  live only as long as your session.
- **Waivers.** A worker may ask to skip a check lane. Accept it when the
  lane cannot observe the change (its inputs are byte-identical, such as
  goldens unchanged or a type moved without edits), and make the worker
  write that claim into the waiver reason and its proof. Refuse it when the
  change touches what the lane exists to prove, such as moving the harness
  the lane runs.
- **Archive refuses** while a turn runs, a Remote Control client is
  attached, or a message is queued. Retry after the session's next report,
  or tell the owner to archive it from the sidebar.
- **Check the title and cwd before every `archive_session` call.** A batch of
  archives once hit an unrelated repo's session with an open PR.
  `unarchive_session` restores it at once. Never archive another repo's
  sessions unless asked.
- **Workers share one machine.** They kill only PIDs they started (a name
  match once killed four other sessions' CI watchers). They never post
  Command + a letter key code, because key codes are layout positions. On
  AZERTY, "Cmd+A" is Cmd+Q, and a probe quit the Claude desktop app. A
  safety check that refused stays refused until the owner changes it.

## Not possible

- A session waking itself when idle, or reading your ledger. Send it the go.
- Owner approval by proxy, in either direction.
- Archiving a session with a running turn or an attached Remote Control
  client.

`reference/worked-example.md` shows one real scheduler (a single self-hosted
Mac runner). `reference/incidents.md` holds the evidence behind each gotcha.
