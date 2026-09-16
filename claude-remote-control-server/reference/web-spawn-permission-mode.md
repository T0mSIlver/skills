# Permission mode for spawned sessions

`PERMISSION_MODE` adds `--permission-mode` to the server, and the server passes
it to every session it spawns. The installer accepts `acceptEdits`, `auto`,
`bypassPermissions`, `manual`, `dontAsk`, `plan`, and `default`. It rejects
anything else, so a typo cannot leave a unit that crash-loops.

Sessions started from claude.ai/code ignore the flag. The web sends its own mode
with every spawn, and its picker offers only Manual, Accept edits, and Plan.
Rules in the repo's `.claude/settings.json` `permissions.allow` apply in every
mode, so they are the way to stop approval prompts in those sessions.

The mode a session really runs in is in its transcript. The process arguments
and the claude.ai mode dropdown both mislead, and the UI never shows bypass even
when it is on:

```bash
grep -o '"permissionMode":"[^"]*"' ~/.claude/projects/<session-slug>/*.jsonl
```

To confirm a reinstall changed the server's flag:

```bash
systemctl --user cat claude-rc-myapp.service | grep -- --permission-mode
```

## Evidence

Live test on 2026-08-04 with CLI 2.1.220, on Linux under user systemd. The
`claude-rc-skills.service` unit had `PERMISSION_MODE=bypassPermissions`:

```
ExecStart=... claude remote-control --name "skills@sandbox" \
  --remote-control-session-name-prefix "sandbox-skills" \
  --spawn worktree --capacity 12 --permission-mode bypassPermissions
```

The server passed the flag on. The session spawned from claude.ai/code during the
test had it on its command line, like every other `cse_*` child:

```
$ ps -eo pid,lstart,args | grep -F -- '--sdk-url'
1027786 Tue Aug  4 19:38:26 2026 .../claude/versions/2.1.220 --print \
  --sdk-url https://api.anthropic.com/v1/code/sessions/cse_01MrMkrbUmHsYp54aVQ5t1JT \
  ... --permission-mode bypassPermissions
```

The session's transcript shows the mode that took effect:

```
$ grep -o '"permissionMode":"[^"]*"' \
    ~/.claude/projects/-home-dev-work-skills--claude-worktrees-bridge-cse-01MrMkrbUmHsYp54aVQ5t1JT/*.jsonl
"permissionMode":"default"
```

The web UI then stopped on the session's first Bash call to ask for approval. An
earlier web-spawned session, `cse_01CyJfuhBBRn5dgV8Wk6aFXV` from 2026-07-07,
also recorded `"permissionMode":"default"`.

[anthropics/claude-code#71518](https://github.com/anthropics/claude-code/issues/71518)
reports the same thing. The CLI parser accepts the flag, and the connected
client ignores it. The [permission modes](https://code.claude.com/docs/en/permission-modes)
docs say bypass cannot be picked from the app and is never reported to the UI,
but they don't mention the client overriding the server flag.

To retest after a CLI upgrade, spawn a session from claude.ai/code and grep its
transcript as above. If it ever records `"bypassPermissions"`, update SKILL.md.
