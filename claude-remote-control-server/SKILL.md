---
name: claude-remote-control-server
description: Install, update, inspect, or troubleshoot persistent Claude Code Remote Control servers for repositories. Use when the user asks to run `claude remote-control`, create a repo-specific remote-control server, make it survive reboots, manage user systemd services such as `claude-rc-skills.service`, configure `--spawn worktree`, service names, session names, prefixes, capacity, permission modes for spawned sessions (`--permission-mode`, `bypassPermissions`), lingering, or add another repo to claude.ai/code remote control.
compatibility: Linux with user systemd (loginctl lingering); the claude CLI logged in via claude.ai. Setup runs the bundled scripts/install-claude-rc-server-service.sh.
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

## Operate

```bash
systemctl --user restart claude-rc-myapp.service
systemctl --user stop claude-rc-myapp.service
systemctl --user disable --now claude-rc-myapp.service
journalctl --user -u claude-rc-myapp.service -f
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
