---
name: claude-remote-control-server
description: Install, update, inspect, or troubleshoot persistent Claude Code Remote Control servers for repositories. Use when the user asks to run `claude remote-control`, create a repo-specific remote-control server, make it survive reboots, manage user systemd services such as `claude-rc-skills.service`, configure `--spawn worktree`, service names, session names, prefixes, capacity, permission modes for spawned sessions (`--permission-mode`, `bypassPermissions`), lingering, keep servers working across CLI auto-updates (`claude-rc-refresh.timer`), fix sessions that fail to start from claude.ai/code (`Session failed`, `ENOENT` spawn errors), or add another repo to claude.ai/code remote control.
compatibility: Linux with user systemd (loginctl lingering); the claude CLI logged in via claude.ai. Setup runs the bundled scripts/install-claude-rc-server-service.sh, which also enables a timer running scripts/refresh-claude-rc-servers.sh.
---

# Claude Remote Control Server

Manage long-lived `claude remote-control` server mode for repos. This is for
user-dispatched work from claude.ai/code or the Claude app. It is separate from
delegated prompted Claude runs, which use `claude-rc-spawn`.

## Install Or Update

From the target repo, install or update its service:

```bash
install-claude-rc-server-service.sh
```

Install another repo with explicit names:

```bash
REPO_DIR="$HOME/work/myapp" \
SERVICE_NAME=claude-rc-myapp \
SESSION_NAME="myapp@$(hostname -s)" \
SESSION_PREFIX="$(hostname -s)-myapp" \
CAPACITY=8 \
install-claude-rc-server-service.sh
```

Defaults are derived from the repo directory name and the short hostname, so the
explicit form above is only needed to override them. Use one user systemd service
per repo, and pick distinct `SERVICE_NAME`, `SESSION_NAME`, and `SESSION_PREFIX`
values so sessions are easy to identify in claude.ai/code.

`DRY_RUN=1` prints the unit it would write to stdout and exits without touching
disk or systemd — preview a config change, or diff it against the live unit:

```bash
svc=claude-rc-skills   # the service you are comparing against
DRY_RUN=1 CAPACITY=12 SERVICE_NAME="$svc" install-claude-rc-server-service.sh \
  | diff - <(systemctl --user cat "$svc.service" | tail -n +2)
```

`systemctl --user cat` prepends a `# /path` line, hence the `tail`. Pass the same
overrides the service was installed with, or the diff reports those as changes.

Validation still runs under `DRY_RUN`, so it also checks a `PERMISSION_MODE`
value without installing. `DRY_RUN=0`, `false`, and `no` mean off, case- and
space-insensitively.

## CLI Updates

A server spawns every session from its own versioned binary under
`~/.local/share/claude/versions/`. The native updater deletes old versions it
does not see locked, and a version lock holds a single PID, so a server that
did not win the lock at startup can lose its binary while it runs. From then on
every session started from claude.ai/code fails within a second with
`spawn error: ENOENT`, while systemd still reports the service `active` and
claude.ai/code still lists the environment.

The installer also enables `claude-rc-refresh.timer`, one for all servers.
Every 5 minutes it restarts each `claude-rc-*` server whose binary differs from
the one `claude` points to, once none of the server's sessions is mid-turn:

- A session is mid-turn unless `~/.claude/sessions/<pid>.json` says
  `"status":"idle"`.
- CLI 2.1.258 and older record no status; their sessions count as mid-turn
  until the transcript has been quiet for 15 minutes (`QUIET_MINUTES`).

A restart keeps the environment and every session in it. The old server stops
each session's process, and the new one respawns a session with its history
when it is next messaged:

- A worktree with uncommitted changes, untracked files, or commits since it was
  created is kept, and the session resumes in it.
- A worktree with none of those is removed with its branch at shutdown and
  recreated from the same base commit on the next message. Gitignored contents
  such as `node_modules` or build output are lost with it.
- The session in the repo checkout is respawned right away.

Verified 2026-09-16 on CLI 2.1.273. Evidence and the alternatives weighed are in
[reference/cli-update-stale-binary.md](reference/cli-update-stale-binary.md);
the bug is tracked upstream as
[anthropics/claude-code#84817](https://github.com/anthropics/claude-code/issues/84817).

Preview what the next run would do, and read what past runs did:

```bash
DRY_RUN=1 refresh-claude-rc-servers.sh
journalctl --user -u claude-rc-refresh.service -n 20 --no-pager
```

The timer runs a copy at `~/.local/share/claude-rc/refresh-claude-rc-servers.sh`;
re-run the installer for any repo to update it.

## Permission Mode For Spawned Sessions

`PERMISSION_MODE` sets `--permission-mode` on the server, and every session it
spawns starts with that flag on its command line. Accepted values are the CLI's
own choices — `acceptEdits`, `auto`, `bypassPermissions`, `manual`, `dontAsk`,
`plan` — plus the undocumented but working `default`; the installer rejects
anything else instead of writing a unit that crash-loops. Omit it to keep the
CLI default.

```bash
REPO_DIR="$HOME/work/myapp" \
PERMISSION_MODE=bypassPermissions \
install-claude-rc-server-service.sh
```

Sessions spawned from claude.ai/code do not currently honor this flag: the web
UI sends its own permission mode with every spawn (its picker offers only
Manual, Accept edits, and Plan), and the client-sent mode overrides the server
flag. The spawned process carries `--permission-mode bypassPermissions`, yet
its transcript records `"permissionMode":"default"` and Bash calls still stop
for approval in the UI. Verified 2026-08-04 on CLI 2.1.220 — evidence in
[reference/web-spawn-permission-mode.md](reference/web-spawn-permission-mode.md);
tracked upstream as
[anthropics/claude-code#71518](https://github.com/anthropics/claude-code/issues/71518).

For prompt-free remote sessions, use `permissions.allow` rules in the repo's
`.claude/settings.json` instead — those apply in every mode, including the
Manual mode web spawns land in. To check the mode a session actually runs in,
read `"permissionMode"` from its transcript under `~/.claude/projects/`; the
process arguments and the claude.ai mode dropdown both mislead (bypass is
never reported to the UI even when active).

Changing the mode is a reinstall — re-run the installer with the new
`PERMISSION_MODE` value, then confirm the flag landed:

```bash
systemctl --user cat claude-rc-myapp.service | grep -- --permission-mode
```

## Verify

```bash
systemctl --user status claude-rc-myapp.service
journalctl --user -u claude-rc-myapp.service -n 80 --no-pager
loginctl show-user "$USER" -p Linger
```

Expect the service to be `active`, linger to be `Linger=yes`, and the journal to
show the current claude.ai/code environment URL.

`active` does not mean sessions can start. The server's session events carry
terminal escape codes, so plain `journalctl` shows them as `[171B blob data]`,
buried in several status redraws a second. Read them with `-a` over a time
window rather than a line count:

```bash
journalctl --user -u claude-rc-myapp.service --since -1d -a -o cat --no-pager \
  | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' | grep -E '^\[[0-9:]+\] ' | uniq
```

## Troubleshoot Sessions That Fail To Start

- `Session failed: spawn error: ENOENT ... posix_spawn '.../versions/<version>'`:
  the server's binary was deleted by a CLI update, and
  `readlink /proc/<server pid>/exe` ends in `(deleted)`. Restart the service, or
  wait for `claude-rc-refresh.timer`.
- `Session failed: Process exited with error` right after every restart, for the
  same `cse_...` ID: the server is re-adopting the session recorded in
  `~/.claude/projects/<repo-slug>/bridge-pointer.json`, and that session was
  archived on claude.ai. New sessions are unaffected. Moving the pointer aside
  stops the error, but the server then registers a new environment, so
  claude.ai/code lists the repo under a new environment ID.
- Anything else: restart with `--debug-file <path>` added through a temporary
  drop-in (`~/.config/systemd/user/claude-rc-myapp.service.d/`). The server
  writes each session's log next to it as `<path stem>-cse_....log`, and the
  session's own exit reason is in there.

## Operate

```bash
systemctl --user restart claude-rc-myapp.service
systemctl --user stop claude-rc-myapp.service
systemctl --user disable --now claude-rc-myapp.service
journalctl --user -u claude-rc-myapp.service -f
systemctl --user list-timers claude-rc-refresh.timer
```

## Rules

- Use `--spawn worktree` for repo servers so each remote-dispatched session gets
  its own Claude-managed git worktree.
- Keep server mode under systemd for reboot survival. Do not rely on tmux alone.
- Unset `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_API_KEY`,
  `ANTHROPIC_AUTH_TOKEN`, and non-default `ANTHROPIC_BASE_URL` for Remote
  Control services so Claude can use the local full claude.ai login.
- Keep `Restart=always`, `RestartSec=30`, and `StartLimitIntervalSec=0` so the
  service keeps retrying through reboot, network, or temporary auth trouble.
- Set the permission mode through `PERMISSION_MODE` at install time rather than
  hand-editing `ExecStart`, so the next reinstall does not silently drop it.
- Keep `claude-rc-refresh.timer` enabled. Without it, a server left running
  across a few CLI releases can stop starting sessions.
