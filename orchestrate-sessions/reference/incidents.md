# Incidents behind the rules

All from one scheduler session on T0mSIlver/localvoxtral, 2026-09-26
(about 40 chips spawned, 60 archive calls, 200 messages), and the project
memory it wrote. Times are UTC.

| Rule | What happened |
|---|---|
| Search `list_sessions` titles, not only open PRs, before spawning | A chip for #728 duplicated a session already running the same measurements on the shared GPU. It had pushed a branch but opened no PR. Caught 17:22; the duplicate got a queued "stop, kill only your PIDs" message, then `stop_session`. |
| Replace a chip by spawning, then dismissing | A #316 chip needed one more path in its prompt. The new chip went up first, then `dismiss_task` on the old one with "superseded by …". |
| Times in UTC, offset spelled out | The scheduler booked the Mac 20:00–20:45 UTC and told a session "19:45". The session's Mac clock read two hours ahead, so it took Paris time and set its undo-ready deadline for 17:40 UTC. |
| `CronCreate` is local time | The box runs CEST. A 19:54 UTC wake-up was written `54 21 26 9 *` after `date`. The jobs are session-only and die when Claude exits. |
| Idle sessions don't wake | The #568 eval session was idle with no timer ahead of its 20:00 UTC slot; the scheduler set one-shot crons to send it, and two later sessions, their go. |
| Pre-merge `+pull/N/head` refetch | A session rebased and force-pushed while the scheduler watched it. Without `+`, the fetch into an existing `prN` ref is refused as non-fast-forward and the local ref stays stale. |
| Build the combined tree | #712 was green on every check. #710 had merged minutes earlier and added `test-reads.txt` with a completeness check. Running that check on #712 merged with main failed: one new test read a README the list didn't name. Merged as it stood, it would have turned main's linux job red. |
| Clean `merge-tree` is not compatibility | #664 changed an enum case to `.root(String, mainCheckout:)`; #665 added a test binding `.root(let reported)`. Clean textual merge, both green alone, main's test target stopped compiling (fixed by #688). Same day, #686 after #648: an exhaustive switch missed a new case (fixed by #694). |
| Rerun reuses the old merge ref | After main broke, affected PRs' `gh run rerun` rebuilt the same old merge commit. A new push was needed. |
| Merge rights | Owner: "prioritize merging the CI, opt-out PRs and the PRs that will make other PRs faster" (merge on green). Features needed "LGTM on #n". Later that day: "merge it on green, I'll check later". Other sessions refused an owner OK relayed by the scheduler; the owner answered them directly. |
| `--delete-branch` and worktrees | `gh pr merge --squash --delete-branch` merged remotely, then failed locally because an old session's worktree held the branch. `git push origin --delete <branch>` finished it. |
| Address sessions by id | `SendMessage` to a session title failed with "No agent named … is reachable" for a session `ListAgents` didn't list. Messages to the `local_…` session id (through `SendMessage` or the older `send_message`) reached every local session. 36 deliveries were immediate, 25 queued behind a running turn. |
| Waivers | Accepted: "enums moved unchanged", "no prompt, pin, sampling or request-shape change (goldens green)", "logging-only, returns no different value". Refused: moving the eval harness the LLM lane runs, since the lane run is the proof the harness still works. |
| Archive refusals | 29 of about 60 archive calls were refused: "still working (a turn in progress)" or "still has live work (an agent run, a Remote Control client, a queued message or a background task)". |
| Check title and cwd before archiving | A batch of three archives included "PR codex reviews and evaluation", a session in another repo with an open PR and an armed overnight bench timer. Restored with `unarchive_session` within the minute; nothing lost. |
| Kill only your own PIDs | A session ending its work ran a name match on `watch-checks.sh` and killed four other sessions' CI watchers. Earlier, `killmatch "python3 -"` killed another project's MCP server. |
| No Command + letter key codes | A #660 probe cleared a text box with Command + virtual key 0: A on US, Q on the owner's ABC-AZERTY layout. It pressed Cmd+Q nine times and quit Claude Desktop. Its frontmost-app guard read a stale value from a script with no run loop, and the session had relaxed a safety check after the probe first refused. |
| Broadcast rule changes | 11:41 the owner switched reviews to GLM through Vibe (GLM quota nearly spent); 14:11 back to GLM when its window reset. Each switch went to every running session. |
| Workers watch CI in the background | #674 and #692 sat idle on green drafts for an hour and more before the scheduler nudged them. From then on every go said to run the watcher with `run_in_background` and report when it ends. |
| Keep a ledger | The scheduler compacted at 15:42. Its bookings, merge queue and session list survived because they were in `project-status.md`. |
