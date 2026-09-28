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

## 2026-09-27 (same repo, second day)

| Rule | What happened |
|---|---|
| Session crons don't fire when idle; use background wake-ups and systemd timers | Nothing ran between 02:31 and 05:03 UTC although the one-shot crons were set; background tasks kept running. GitHub's own schedules also fired late or not at all that night (no nightly, no weekly eval). The next night used `orch-wakeat` and two dev-box systemd user timers that refuse outside the window. |
| Merge ref lag; count landings from before the run | #806 and #845 were each green; together they broke main's test build (fixed by #866). #845 landed minutes before #806's run was created, and the run's merge ref didn't include it. |
| Exclude the PR's own ancestors from "landed since" | After widening the window, the check flagged #866's own base commit as an overlap. `git log origin/main ^prN` fixed it. |
| A combo goes stale when main moves | #797's combo on be00dfd0 passed, but the docs rework landed before the merge and touched the same files; a second combo on the new main was needed. |
| Conflicting PRs get no runs | #806 sat with mac-lanes at its draft skip: ready and draft toggles started nothing because the branch conflicted with main. The evening before a night window, four of seven booked PRs conflicted with main on docs files. |
| Stack PRs sharing files | #885 (docs rework) conflicted after #878 landed, #905 (menu bar marks) after #901 (needs-you sound): each cost a round trip through its session and a new CI run. Stacked on the PR ahead of it, each would have merged on its own run. |
| Concurrency group replaces the pending run | The weekly eval on main was cancelled because a second dispatch (for #742) went pending behind it in the same group. Dispatch the next one only after the previous run has started. |
| A dispatch uses the ref's workflow file | #742's eval hung because its branch predated the stall fail-fast in the workflow; merging main into the branch fixed it. |
| A skipped must-run check reads as green | The scheduler told the owner a non-required check (`dogfood`) was required; it corrected this. The real trap is the other way: mac-lanes skips drafts, and GitHub counts that skip as passing, so the scripts require a real success. |
| Peers misstate rules | A session said its PR had to wait for the owner's card move before merging. The owner's standing rule was merge on green, then route the card to his hand check; the scheduler merged and told the session. |
| Archive deletes the worktree | The night plan pointed at a session's worktree for its runs; archiving that session removed it. The plan now fetches the PR head into a fresh worktree. |
| zsh doesn't word-split | `for p in "a b" …; do script $p` passed "a b" as one argument and every pair tested the wrong thing. |
| Scratchpad scripts are lost | The merge scripts lived in the session scratchpad; a successor would have had none. They moved into this skill with a per-repo config. |

## 2026-09-28 (same repo, third day)

| Rule | What happened |
|---|---|
| A data-loss report comes first, in this order | The owner's History went empty. The scheduler stopped other work and backed up the three store files before anything else could write them. It read the store read-only through a terminal pane on the owner's Mac, and restored 652 records from `sqlite3 .recover` only on the owner's go. Then it spawned the fix, ran two whole-repo audits (GLM and Codex), filed a tracking issue with five sub-issues, and installed hourly backups until the fix ships. |
| A runner on the owner's machine runs as the owner | The self-hosted runner ran each PR's launch smoke as the owner's user, sharing the app's data store with the installed app. Schema changes from PR builds migrated that store back and forth. Night eval dispatches now wait for a fresh backup. |
| Data-safety PRs get two reviewers | The owner: "Do a Codex review on top of the GLM review … spend some time on that so that we don't lose data anymore." |
| Metered quota is a resource | The owner: "use the Codex 5-hour limits as soon as they're available with Astra … The goal is to not waste limits at all." A queue runner slept through a spent window and ran the reviews when it reopened; it now lives with the `quota` skill. |
| Rewriting main needs the owner | A background agent wrote an AI co-author trailer by hand into its commits, and the squash merge copied it onto main's tip. On the owner's go, and after the owner deactivated the branch ruleset, the scheduler rewrote that commit's message and force-pushed with `--force-with-lease`; the tree stayed identical. |
| Chips while the owner is present | The owner corrected "subagent" to "session" twice (2026-09-27 09:00: "I meant a session not subagent"; 2026-09-28 09:26: "spawn sessions, not subagents now that I'm back at the mac"). |
| Clean up without being asked | The owner asked for an archive round six times in three days ("Archive sessions that are done", "archive sessions that can be", "Don't forget to archive sessions that can be archived"). |
| Keep the pipeline full | 2026-09-27 16:07, the owner: "you're only orchestrating three sessions right now. So there's still stuff we could do. Spawn sessions for those." |
| A night's latitude expires | 2026-09-27 22:29, the owner: "tonight merge everything that inference confirms. You have full latitude." Recorded as that night only. |
| Fleet agent definitions | A fleet of five test-pruning subagents needed a fixed model and effort. `~/.claude/agents/test-pruner.md` pinned both. The scheduler's own `sonnet` alias still meant the previous Sonnet: it had started on an older Claude Code version. |
| `orch-combowatch` takes the combo PR number | Given `combo/966-on-1049a3fd`, it polled `pulls/combo/…` (a 404) until stopped. It now resolves a branch and fails fast. |
| `SKIP` is space-separated | A comma list is one token that matches no PR, so the poller held nothing. The script now accepts commas and refuses non-numbers. |
| `orch-cardmove` read-back | It printed `#1001 ` with no status while the item list lagged the edit. It now re-reads and exits 1 if no status shows. |
| Dispatch after the previous run started | Each night dispatch ran `gh workflow run` then `sleep 20; wait-started.sh`; without the sleep the helper read the previous, finished run. `orch-dispatch` dates its own run instead. |

The project board: the owner keeps a browser tab of issues and PRs and
doesn't open the board. The label stays the hand-check signal; the board
steps stay optional (`BOARD_NUMBER` empty).
