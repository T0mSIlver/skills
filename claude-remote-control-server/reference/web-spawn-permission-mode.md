# Evidence: claude.ai/code spawns override the server's `--permission-mode`

Live test, 2026-08-04, CLI 2.1.220 (Linux, user systemd). The
`claude-rc-skills.service` unit was installed with
`PERMISSION_MODE=bypassPermissions`:

```
ExecStart=... claude remote-control --name "skills@sandbox" \
  --remote-control-session-name-prefix "sandbox-skills" \
  --spawn worktree --capacity 12 --permission-mode bypassPermissions
```

The server does pass the flag to every session it spawns — the session spawned
from claude.ai/code during the test (and every other `cse_*` child) carries it
on its command line:

```
$ ps -eo pid,lstart,args | grep -F -- '--sdk-url'
1027786 Tue Aug  4 19:38:26 2026 .../claude/versions/2.1.220 --print \
  --sdk-url https://api.anthropic.com/v1/code/sessions/cse_01MrMkrbUmHsYp54aVQ5t1JT \
  ... --permission-mode bypassPermissions
```

But the connected client overrides it. The claude.ai/code spawn dialog offers
only Manual, Accept edits, and Plan, and submits a mode with every spawn. The
session's transcript shows the mode that actually took effect:

```
$ grep -o '"permissionMode":"[^"]*"' \
    ~/.claude/projects/-home-dev-work-skills--claude-worktrees-bridge-cse-01MrMkrbUmHsYp54aVQ5t1JT/*.jsonl
"permissionMode":"default"
```

and the web UI stopped on the session's first Bash call to ask for approval.
A second web-spawned session on record (2026-07-07,
`cse_01CyJfuhBBRn5dgV8Wk6aFXV`) shows the same `"permissionMode":"default"`,
so this is consistent, not a one-off.

Upstream: [anthropics/claude-code#71518](https://github.com/anthropics/claude-code/issues/71518)
reports the same symptom ("accepted by the CLI parser, no effect on the
connected client"). Official docs
([permission modes](https://code.claude.com/docs/en/permission-modes)) confirm
bypass cannot be selected from the app and is never reported back to the UI,
but do not document the client override of the server flag.

Retest after CLI upgrades by spawning a session from claude.ai/code and
grepping its transcript as above; if it ever records `"bypassPermissions"`,
update SKILL.md.
