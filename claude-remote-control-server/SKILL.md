---
name: claude-remote-control-server
description: Install, change, or troubleshoot per-repo `claude remote-control` (RC) servers under user systemd, which let claude.ai/code start sessions on this machine.
compatibility: Linux with user systemd and lingering; the claude CLI logged in via claude.ai.
---

# Claude Remote Control server

Each repo gets one user systemd service running
`claude remote-control --spawn worktree`, so claude.ai/code and the Claude app
can start sessions in it, each in its own git worktree. Prompted runs you
delegate yourself use `claude-rc-spawn` instead.

## Install or change a server

Run the installer from the repo. To change a server, run it again with the new
values.

```bash
CAPACITY=8 install-claude-rc-server-service.sh
```

| Variable | Default |
|----------|---------|
| `REPO_DIR` | the current git checkout |
| `SERVICE_NAME` | `claude-rc-<repo>` |
| `SESSION_NAME` | `<repo>@<host>` |
| `SESSION_PREFIX` | `<host>-<repo>` |
| `CAPACITY` | `8` |
| `PERMISSION_MODE` | the CLI's default |

`DRY_RUN=1` prints the unit instead of installing it. To preview a change, pass
the values the service was installed with plus the new one, and diff:

```bash
DRY_RUN=1 SERVICE_NAME=claude-rc-myapp CAPACITY=12 install-claude-rc-server-service.sh \
  | diff - <(systemctl --user cat claude-rc-myapp.service | tail -n +2)
```

The installer also enables `claude-rc-refresh.timer`. A CLI auto-update can
delete the binary a server starts sessions from, so the timer restarts servers
left on an old CLI once no session is mid-turn. Sessions pick up again on their
next message. See [reference/cli-updates.md](reference/cli-updates.md).

Sessions started from claude.ai/code ignore `PERMISSION_MODE`, because the web
sends its own mode. To stop approval prompts, add `permissions.allow` rules to
the repo's `.claude/settings.json`. See
[reference/web-spawn-permission-mode.md](reference/web-spawn-permission-mode.md).

## Check a server

```bash
systemctl --user status claude-rc-myapp.service
loginctl show-user "$USER" -p Linger
```

Expect `active` and `Linger=yes`. `active` only means the process is up. When
sessions fail to start, plain `journalctl` hides the errors as
`[171B blob data]`; [reference/cli-updates.md](reference/cli-updates.md#troubleshooting)
shows how to read them.

Change a server by re-running the installer, not by editing its unit. The
installer strips `ANTHROPIC_API_KEY` and similar variables so the server uses
the claude.ai login, and the next install overwrites hand edits.
