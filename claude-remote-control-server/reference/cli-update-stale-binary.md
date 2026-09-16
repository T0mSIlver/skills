# Evidence: CLI auto-updates delete a running server's binary

Incident, 2026-09-16, CLI 2.1.259 → 2.1.273 (Linux, user systemd).
`claude-rc-job-search.service` had run since 2026-09-03. Every session started
from claude.ai/code that day failed within a second, while the service stayed
`active` and claude.ai/code kept listing the environment.

## Symptom

The failures only show with `journalctl -a`; plain output renders them as
`[171B blob data]`:

```
[17:32:22] Session failed: spawn error: ENOENT: no such file or directory, posix_spawn '/home/dev/.local/share/claude/versions/2.1.259' cse_01EgG4V42kpxCsQeqDTknX1t
[19:17:43] Session failed: spawn error: ENOENT: no such file or directory, posix_spawn '/home/dev/.local/share/claude/versions/2.1.259' cse_01KyVpKMirTJmZHC7nxUbFNt
[19:41:33] Session failed: spawn error: ENOENT: no such file or directory, posix_spawn '/home/dev/.local/share/claude/versions/2.1.259' cse_01ATR3hQy1LAb2HSLs3KBEaA
```

The server was still running the deleted binary, and the launcher had moved on:

```
$ ls -l /proc/1682158/exe ~/.local/bin/claude
/proc/1682158/exe -> /home/dev/.local/share/claude/versions/2.1.259 (deleted)
~/.local/bin/claude -> /home/dev/.local/share/claude/versions/2.1.273
```

Sessions are direct children of the server, exec'd from the server's own
versioned path, never through the launcher:

```
$ ps -o pid,ppid,etime,args --ppid 221
    PID    PPID     ELAPSED COMMAND
    891     221 14-01:38:09 /home/dev/.local/share/claude/versions/2.1.258 --print --sdk-url https://api.anthropic.com/v1/code/sessions/cse_01AA9thjCLDDtgk22aW8yVqG ...
```

## Why the version was deleted

`~/.local/state/claude/locks/` holds one file per protected version, and each
records a single PID:

```
$ ls ~/.local/state/claude/locks/
2.1.258.lock  2.1.267.lock  2.1.273.lock
$ cat ~/.local/state/claude/locks/2.1.258.lock
{
  "pid": 219,
  "version": "2.1.258",
  "execPath": "/home/dev/.local/share/claude/versions/2.1.258",
  "acquiredAt": 1788365730191
}
```

There was no `2.1.259.lock`. A process that starts on a version whose lock is
already held logs the failure and runs on without a lock. The restarted
job-search server's debug log:

```
[ERROR] NON-FATAL: Lock acquisition failed for /home/dev/.local/share/claude/versions/2.1.273 (expected in multi-process scenarios): Lock already held by another process
```

`cleanupOldVersions` in the 2.1.273 bundle protects only three kinds of
version: the cleaning process's own `process.execPath`, the launcher's target,
and versions whose PID lock belongs to a live Claude process. From the rest it
keeps a few of the newest and deletes the others; on this machine 2.1.270 and
2.1.271 survived without a lock while the older 2.1.259 was gone. So once the process holding a version's lock
exits, every other process still running that version is unprotected. Any
`claude` process on the machine can run the cleanup, so setting
`DISABLE_AUTOUPDATER` on the server does not help.

## Restarts keep the environment

Restarting the service on 2.1.273, with one idle session open in the repo
checkout:

```
[19:56:23] Shutting down 1 active session(s)…
[19:56:23] Environment preserved. Restart `claude remote-control` to reconnect existing sessions.
```

The new server came up in the same environment
(`env_01YSW6GXC5fsxB2Pcq4QEPQ9`) and spawned a new child for the same session,
`cse_01KUMWs4N3MLieCSGwfexGzb`, which kept running. The session to re-adopt comes
from `~/.claude/projects/<repo-slug>/bridge-pointer.json`.

## Worktree sessions survive a restart

Two sessions were created from claude.ai/code on the same server, then left idle:

- A: "Create a file rc-restart-test.txt containing the word alpha. Don't commit."
- B: "Run git rev-parse HEAD and reply with the hash. Don't change any files."

`refresh-claude-rc-servers.sh`, run with `CLAUDE_BIN` pointed at an older
version, restarted the server:

```
claude-rc-job-search.service: restarting from 2.1.273 (outdated) onto 2.1.271 with 3 idle session(s)
[21:42:55] Shutting down 3 active session(s)…
[21:42:55] kept worktree .../bridge-cse_01DGi7UP4XZRYueLfybrDbTX · uncommitted changes
[21:42:55] removed worktree .../bridge-cse_016L3NE3683uwjZRycTBSfLd
[21:42:56] Environment preserved. Restart `claude remote-control` to reconnect existing sessions.
```

B's branch `worktree-bridge-cse_016L3NE3683uwjZRycTBSfLd` was deleted with its
worktree. The new server re-queued only the repo-checkout session; A and B had
no process until messaged. claude.ai/code showed nothing unusual. A follow-up to
each respawned it with `--resume` from the server's copy of the conversation:

```
[bridge:session] Created worktree for sessionId=[REDACTED] at .../bridge-cse_01DGi7UP4XZRYueLfybrDbTX
[bridge:session] Child args: --print --sdk-url .../cse_01DGi7UP4XZRYueLfybrDbTX ... --resume=https://api.anthropic.com/v1/code/sessions/cse_01...
```

A answered from its kept worktree and its history: "`rc-restart-test.txt`
contains `alpha`. It's still uncommitted. Your first message was: …". B's
worktree was recreated at the same commit, and it answered "Earlier I reported
`cadfc49…`. Running `git rev-parse HEAD` again gives the same hash".

The cleanup rule comes from the 2.1.273 bundle. At shutdown each active
session's worktree is removed, with `git branch -D` on its branch, unless
`git status --porcelain` shows anything (untracked files count) or
`git rev-list --count CLAUDE_BASE..HEAD` is non-zero. `CLAUDE_BASE`, in the
worktree's git directory, is written when the worktree is created and read back
on every respawn, so commits made before an earlier restart still count.
Ignored files do not show in `git status`, so a worktree holding only ignored
files is removed.

A plain SIGTERM does not record the active sessions for re-queuing at startup.
That path is reserved for shutdown causes `upgrade`, `reload`, and `yield`,
which the `claude daemon` supervisor reports to the remote-control workers it
runs. On 2.1.273 its help reads
"Service install is disabled in this version — the daemon runs on demand and
exits when the last client disconnects", so it cannot replace the systemd units
yet. [#88166](https://github.com/anthropics/claude-code/issues/88166) asks for a
supported persistent service.

When the recorded session has been archived on claude.ai, re-adoption fails on
every restart, which does not affect new sessions. The server's debug log shows
`reconnectSession(...) failed: ReconnectSession: Failed with status 400: Session not found.`,
and the child's shows
`CCRClient: Epoch mismatch (409, reason=session_not_active), shutting down`.

## Session status

Every session writes `~/.claude/sessions/<pid>.json`, whose `procStart` equals
field 22 of `/proc/<pid>/stat`. Sessions spawned by 2.1.273 carry `"status"`;
the values seen across all session files were `idle`, `busy`, and `waiting`.
The 18 spawned-session files from 2.1.246 to 2.1.258 have no `status`, which is
why `refresh-claude-rc-servers.sh` falls back to transcript age for them.

## Alternatives weighed

- **Run the server from a hard link outside `versions/`.** Tested: with
  `ExecStart` pointing at `~/.local/share/claude-rc/bin/2.1.273` (a hard link),
  the server and its sessions ran from that path, the session was re-adopted,
  and neither debug log reported an updater or install warning. Cleanup never
  scans that directory, so the server cannot break. Not chosen: a server stays
  on the version it started with until someone restarts it.
- **Restart only when the binary is already `(deleted)`.** Sessions have
  already failed by the time it acts. The refresh script still covers this case,
  since a deleted binary also differs from the launcher's.
- **Make the launcher look externally managed.** Cleanup skips entirely when
  `~/.local/bin/claude` is not the installer's symlink, but that turns cleanup
  off for the whole machine, at about 225 MB per release.
- **Write the lock file for the server's PID.** The lock format is internal and
  holds one PID, so it would drop whichever process held it before.

Upstream:
[anthropics/claude-code#84817](https://github.com/anthropics/claude-code/issues/84817)
reports the same ENOENT from a server's pruned install path, with restarting as
the workaround. Retest after CLI upgrades: if a server keeps spawning sessions
after its version is superseded and cleaned up, the timer is no longer needed.
