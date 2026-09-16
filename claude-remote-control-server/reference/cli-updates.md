# CLI updates and sessions that fail to start

A server starts every session from its own versioned binary under
`~/.local/share/claude/versions/`. The native updater deletes old versions it
doesn't see locked, and a version lock holds a single PID. A server that didn't
get the lock at startup can lose its binary while it runs. After that, every
session started from claude.ai/code dies within a second, and systemd still
reports the service `active`. Upstream tracks this as
[anthropics/claude-code#84817](https://github.com/anthropics/claude-code/issues/84817).

## The refresh timer

`claude-rc-refresh.timer` covers every server and runs every 5 minutes. It
restarts a running `claude-rc-*` server when its binary differs from the one
`claude` points to, or has been deleted, and none of its sessions is mid-turn.

- A session counts as mid-turn unless `~/.claude/sessions/<pid>.json` says
  `"status":"idle"`. If the file's `procStart` doesn't match the process, the
  file belongs to an earlier process with the same PID, and the session counts
  as mid-turn.
- CLI 2.1.258 and older write no status. Those sessions count as mid-turn until
  their transcript has been quiet for 15 minutes, set by `QUIET_MINUTES`.
- A server whose binary lives outside the launcher's versions directory is not a
  native install, and the timer leaves it alone.

```bash
DRY_RUN=1 refresh-claude-rc-servers.sh
journalctl --user -u claude-rc-refresh.service -n 20 --no-pager
systemctl --user list-timers claude-rc-refresh.timer
```

The timer runs a copy of the script at
`~/.local/share/claude-rc/refresh-claude-rc-servers.sh`. Re-run the installer
for any repo to update the copy.

## What a restart does to sessions

The environment and its sessions survive. The old server stops each session's
process, and the new server starts it again, with its history, when the session
gets its next message.

- A worktree with uncommitted changes, untracked files, or commits since its
  creation stays, and the session picks up in it.
- A worktree with none of those is deleted with its branch at shutdown. The next
  message recreates it from the same base commit. Gitignored files such as
  `node_modules` or build output go with it, so that session redoes its setup.
- The session in the repo checkout starts again right away.

## Troubleshooting

Session events contain terminal escape codes, so plain `journalctl` shows them as
`[171B blob data]` between status redraws that arrive several times a second.
Read them with `-a`, over a time window rather than a line count:

```bash
journalctl --user -u claude-rc-myapp.service --since -1d -a -o cat --no-pager \
  | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' | grep -E '^\[[0-9:]+\] ' | uniq
```

- `Session failed: spawn error: ENOENT ... posix_spawn '.../versions/<version>'`
  means a CLI update deleted the server's binary, and
  `readlink /proc/<server pid>/exe` ends in `(deleted)`. Restart the service, or
  wait for the timer.
- `Session failed: Process exited with error` after every restart, always for the
  same `cse_...` ID, means the server is trying to reattach the session in
  `~/.claude/projects/<repo-slug>/bridge-pointer.json`, and that session was
  archived on claude.ai. New sessions still work. Moving the pointer file away
  stops the error, but the server then registers a new environment, and
  claude.ai/code lists the repo under a new environment ID.
- For anything else, add `--debug-file <path>` to `ExecStart` in a temporary
  drop-in under `~/.config/systemd/user/claude-rc-myapp.service.d/` and restart.
  The server writes each session's own log next to that file, named
  `<path stem>-cse_....log`, and the session's exit reason is in it.

# Evidence

## The incident

`claude-rc-job-search.service` had run since 2026-09-03. On 2026-09-16, after
the CLI updated from 2.1.259 to 2.1.273, every session started from
claude.ai/code failed within a second. The service stayed `active` and
claude.ai/code kept listing the environment. The errors only showed with
`journalctl -a`:

```
[17:32:22] Session failed: spawn error: ENOENT: no such file or directory, posix_spawn '/home/dev/.local/share/claude/versions/2.1.259' cse_01EgG4V42kpxCsQeqDTknX1t
[19:17:43] Session failed: spawn error: ENOENT: no such file or directory, posix_spawn '/home/dev/.local/share/claude/versions/2.1.259' cse_01KyVpKMirTJmZHC7nxUbFNt
[19:41:33] Session failed: spawn error: ENOENT: no such file or directory, posix_spawn '/home/dev/.local/share/claude/versions/2.1.259' cse_01ATR3hQy1LAb2HSLs3KBEaA
```

The server still ran the deleted binary, and the launcher pointed at the new one:

```
$ ls -l /proc/1682158/exe ~/.local/bin/claude
/proc/1682158/exe -> /home/dev/.local/share/claude/versions/2.1.259 (deleted)
~/.local/bin/claude -> /home/dev/.local/share/claude/versions/2.1.273
```

Sessions are direct children of the server, started from the server's own
versioned path rather than the launcher:

```
$ ps -o pid,ppid,etime,args --ppid 221
    PID    PPID     ELAPSED COMMAND
    891     221 14-01:38:09 /home/dev/.local/share/claude/versions/2.1.258 --print --sdk-url https://api.anthropic.com/v1/code/sessions/cse_01AA9thjCLDDtgk22aW8yVqG ...
```

## Why the version was deleted

`~/.local/state/claude/locks/` holds one file per locked version, and each file
names one PID. There was no `2.1.259.lock`:

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

A process that starts on a version someone else has locked logs the failure and
carries on without a lock. The restarted job-search server logged:

```
[ERROR] NON-FATAL: Lock acquisition failed for /home/dev/.local/share/claude/versions/2.1.273 (expected in multi-process scenarios): Lock already held by another process
```

In the 2.1.273 bundle, `cleanupOldVersions` spares three kinds of version: the
one the cleaning process runs, the launcher's target, and any version whose lock
PID is a live Claude process. It keeps a few of the newest remaining versions and
deletes the rest. Here 2.1.270 and 2.1.271 survived without a lock, and the older
2.1.259 was gone. Once the lock holder exits, every other process on that version
is unprotected. Any `claude` process on the machine can run the cleanup, so
`DISABLE_AUTOUPDATER` on the server does not help.

## Restarts and worktree sessions

The test used two sessions created from claude.ai/code on the same server and
left idle:

- A: "Create a file rc-restart-test.txt containing the word alpha. Don't commit."
- B: "Run git rev-parse HEAD and reply with the hash. Don't change any files."

`refresh-claude-rc-servers.sh`, with `CLAUDE_BIN` pointed at an older version,
restarted the server:

```
claude-rc-job-search.service: restarting from 2.1.273 (outdated) onto 2.1.271 with 3 idle session(s)
[21:42:55] Shutting down 3 active session(s)…
[21:42:55] kept worktree .../bridge-cse_01DGi7UP4XZRYueLfybrDbTX · uncommitted changes
[21:42:55] removed worktree .../bridge-cse_016L3NE3683uwjZRycTBSfLd
[21:42:56] Environment preserved. Restart `claude remote-control` to reconnect existing sessions.
```

The old server deleted B's branch, `worktree-bridge-cse_016L3NE3683uwjZRycTBSfLd`,
along with its worktree. The new server came up in the same environment and
restarted only the repo-checkout session. A and B had no process until
each got a follow-up message, and claude.ai/code showed nothing unusual. Each
follow-up started the session again with `--resume`, which loads the
conversation from the server:

```
[bridge:session] Created worktree for sessionId=[REDACTED] at .../bridge-cse_01DGi7UP4XZRYueLfybrDbTX
[bridge:session] Child args: --print --sdk-url .../cse_01DGi7UP4XZRYueLfybrDbTX ... --resume=https://api.anthropic.com/v1/code/sessions/cse_01...
```

A read its file from the kept worktree and quoted the first message: "`rc-restart-test.txt`
contains `alpha`. It's still uncommitted. Your first message was: …". B's
worktree came back at the same commit, and B answered "Earlier I reported
`cadfc49…`. Running `git rev-parse HEAD` again gives the same hash".

The cleanup rule is in the 2.1.273 bundle. At shutdown the server removes each
active session's worktree and runs `git branch -D` on its branch, unless
`git status --porcelain` prints anything or
`git rev-list --count CLAUDE_BASE..HEAD` is non-zero. Untracked files show in
that status. Ignored files don't, so a worktree holding only ignored files is
removed. The worktree's git directory stores `CLAUDE_BASE` at creation, and
every respawn reads it back, so commits from before an earlier restart still
count.

A plain SIGTERM doesn't save the active sessions for the next startup. Only the
shutdown causes `upgrade`, `reload`, and `yield` do that, and the `claude daemon`
supervisor is what sends them to the remote-control workers it runs. On 2.1.273
the daemon can't run as a service yet, so it can't replace these units.
`claude daemon --help` says:

```
Service install is disabled in this version — the daemon runs on demand and
exits when the last client disconnects.
```

[#88166](https://github.com/anthropics/claude-code/issues/88166) asks for a
supported persistent service.

When the session in `bridge-pointer.json` has been archived, the server's debug
log shows
`reconnectSession(...) failed: ReconnectSession: Failed with status 400: Session not found.`
and the session's own log shows
`CCRClient: Epoch mismatch (409, reason=session_not_active), shutting down`.

## Session status files

Every session writes `~/.claude/sessions/<pid>.json`. Its `procStart` equals
field 22 of `/proc/<pid>/stat`. Sessions spawned by 2.1.273 include `"status"`,
and the values seen across all session files were `idle`, `busy`, and
`waiting`. None of the 18 spawned-session files from 2.1.246 to 2.1.258 has a
status, which is why the script falls back to transcript age for them.

## Alternatives weighed

- **Run the server from a hard link outside `versions/`.** With `ExecStart`
  pointing at a hard link in `~/.local/share/claude-rc/bin/`, the server and its
  sessions ran from that path, the session reattached, and neither debug log
  showed an updater warning. Cleanup never looks in that directory, so the
  server can't break. It also never updates until someone restarts it, which is
  why the timer won.
- **Restart only when the binary shows `(deleted)`.** By then sessions have
  already failed. The timer covers this case anyway, since a deleted binary also
  differs from the launcher's.
- **Make the launcher look externally managed.** Cleanup skips entirely when
  `~/.local/bin/claude` isn't the installer's symlink. That turns cleanup off for
  the whole machine, and each release adds about 225 MB.
- **Write the lock file with the server's PID.** The format is internal and holds
  one PID, so it would drop whichever process held the lock before.

To retest after a CLI upgrade, check whether a server still starts sessions
after its version is superseded and cleaned up. If it does, the timer is no
longer needed.
