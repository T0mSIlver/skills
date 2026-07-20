---
name: claude-remote-control-server
description: Install, update, inspect, or troubleshoot persistent Claude Code Remote Control servers for repositories. Use when the user asks to run `claude remote-control`, create a repo-specific remote-control server, make it survive reboots, manage user systemd services such as `claude-rc-skills.service`, configure `--spawn worktree`, service names, session names, prefixes, capacity, lingering, or add another repo to claude.ai/code remote control.
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
