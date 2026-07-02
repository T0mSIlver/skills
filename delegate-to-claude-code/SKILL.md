---
name: delegate-to-claude-code
description: Call the Claude Code CLI (`claude`) through Remote Control/tmux, non-interactively, or as a background/worktree run to get a second opinion, run a code review, or delegate read-only or edit-capable work. Use for Claude Code subagent-style delegation, `claude-rc-spawn`, `claude -p`, `--bg`, `--worktree`, `--tmux`, plan/read-only reviewers, acceptEdits/auto edit workers, JSON/stream-json capture, resume flows, and gotchas around permission modes, worktree cleanup, agent personas, and `--dangerously-skip-permissions`.
---

# Delegate to Claude Code (CLI)

Run `claude` for independent investigation, review, or a delegated worker.

There are two separate Remote Control flows:

1. **Prompted delegation from the main agent:** use `claude-rc-spawn`. It starts
   an interactive `claude --remote-control` session inside detached tmux, waits
   for the TUI, pastes the prompt, and presses Enter. The main agent gets a
   tmux/session handle while the user can also watch or steer the session from
   claude.ai/code.
2. **User-dispatched work from claude.ai/mobile:** run a long-lived
   `claude remote-control` server. It does not take an initial prompt and does
   not create a local chat input. It waits for Claude.ai or the Claude app to
   spawn sessions on this machine. For repos that should survive reboots, install
   it as a user systemd service with `scripts/install-claude-rc-server-service.sh`.

Claude Code also has first-class support for `--worktree`, `--bg`,
`claude agents`, `--tmux`, session names, resume, and print-mode budget caps.
Use the noninteractive paths when machine-readable output is more important
than user-visible Remote Control.

## Prerequisites

- Verify `claude` is on PATH with `claude --version`.
- Verify `tmux` and `claude-rc-spawn` are on PATH.
- For a persistent repo Remote Control server, verify `systemctl --user` works.
  Use `loginctl enable-linger "$USER"` so the service starts after reboot
  before an interactive login.
- Verify auth is available with `claude auth login` or `ANTHROPIC_API_KEY`.
- For Remote Control, auth must be a full claude.ai login. API keys,
  `claude setup-token`, and `CLAUDE_CODE_OAUTH_TOKEN` are not enough.
  `claude-rc-spawn` strips token/API-key env vars by default so a local
  claude.ai login can be used from automation shells.
- Run from the target repo, or pass `--add-dir <path>` for extra file access.
- When copying bundled agents, resolve `skill_dir` to the directory containing
  this `SKILL.md`; `assets/...` is not relative to the target repo.

## Step 1 - Choose isolation

For read-only review, stay in the current checkout and use
`--permission-mode plan`.

For edit work, prefer `--worktree <name>` so Claude creates an isolated Git
worktree and branch for the session.

```bash
slug="claude-$(date +%Y%m%d-%H%M%S)"
run_dir=".agent-runs/$slug"
mkdir -p "$run_dir"
```

If the worker must see in-progress local commits, configure Claude Code
`worktree.baseRef` to `head` or create a manual Git worktree from the desired
commit. Otherwise Claude worktrees may start from the remote default branch.

Add `.claude/worktrees/` to `.gitignore` for repos that use Claude-managed
worktrees.

## Step 2 - Write a prompt file

Write the full brief to:

```text
.agent-runs/$slug/prompt.md
```

Include context, exact task, constraints, acceptance criteria, verification
commands, and final output shape. Ask for evidence: command names, exit status,
test output summary, changed files, and remaining risks.

## Step 3 - Pick model and effort

```text
Default: --model opus --effort high
Trivial: --model sonnet --effort low
```

Use `--max-budget-usd <amount>` for foreground `claude -p` unattended runs with
a firm spend cap. In the current CLI this flag is print-mode-only; do not rely
on it for background `--bg` agents.

## Step 4 - Launch the run

### Flow 1: prompted Remote Control tmux session

Use `claude-rc-spawn` when the main agent has a specific brief to hand to
Claude. This is the normal path for a reviewer, second opinion, or delegated
worker. It prints the tmux session, prompt path, log path, and attach command.

Read-only reviewer / second opinion:

```bash
claude-rc-spawn \
  --cwd "$PWD" \
  --prompt-file "$run_dir/prompt.md" \
  --name "$slug-review" \
  --tmux-session "$slug-review" \
  --permission-mode plan \
  --model opus --effort high
```

Edit worker in a Claude-managed worktree:

```bash
claude-rc-spawn \
  --cwd "$PWD" \
  --prompt-file "$run_dir/prompt.md" \
  --name "$slug-edit" \
  --tmux-session "$slug-edit" \
  --permission-mode acceptEdits \
  --worktree "$slug" \
  --model opus --effort high
```

Watch locally with `tmux attach -t "$slug-edit"`. From another device, open
claude.ai/code and select the session by name. Leave the tmux session running
until the Claude task is complete.

Do not use this helper for a server that should sit around waiting for future
mobile/web tasks. `claude-rc-spawn` is intentionally one Claude session per
delegated prompt.

### Flow 2: persistent Remote Control server

Use server mode when the user wants to open claude.ai/code or the Claude app and
spawn fresh sessions on this machine. This is a repo service, not a single
delegated task.

Install or update the service for the current repo:

```bash
scripts/install-claude-rc-server-service.sh
```

Install a second repo service from this repo's installer:

```bash
REPO_DIR=/home/dev/work/localvoxtral \
SERVICE_NAME=claude-rc-localvoxtral \
SESSION_NAME=localvoxtral@devbox \
SESSION_PREFIX=devbox-localvoxtral \
CAPACITY=8 \
scripts/install-claude-rc-server-service.sh
```

The installer writes a user unit like this:

```ini
[Service]
WorkingDirectory=/home/dev/work/localvoxtral
ExecStart=/usr/bin/env -u CLAUDE_CODE_OAUTH_TOKEN -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL \
  /home/dev/.local/bin/claude remote-control \
    --name "localvoxtral@devbox" \
    --remote-control-session-name-prefix "devbox-localvoxtral" \
    --spawn worktree \
    --capacity 8
Restart=always
RestartSec=30
```

`--spawn worktree` gives each on-demand remote session its own git worktree.
Use a repo-specific name/prefix so concurrent machines and repos are easy to
distinguish in claude.ai/code.

Operate the service with:

```bash
systemctl --user status claude-rc-localvoxtral.service
journalctl --user -u claude-rc-localvoxtral.service -f
systemctl --user restart claude-rc-localvoxtral.service
```

If the service should survive reboot before login, confirm:

```bash
loginctl show-user "$USER" -p Linger
```

The output should be `Linger=yes`.

### Fallback: noninteractive capture

Use `claude -p` when you need JSON/JSONL capture and do not need the session to
appear in Remote Control.

Read-only reviewer / second opinion:

```bash
cat "$run_dir/prompt.md" | claude -p \
  --model opus --effort high \
  --permission-mode plan \
  --output-format json \
  --name "$slug-review" \
  --add-dir .
```

`plan` mode allows read/search/read-only shell exploration and blocks source
edits.

### Foreground edit worker

Use `acceptEdits` for a bounded unattended edit worker. Use `auto` when you want
background safety checks around broader tool calls.

```bash
cat "$run_dir/prompt.md" | claude -p \
  --model opus --effort high \
  --permission-mode acceptEdits \
  --worktree "$slug" \
  --output-format stream-json \
  --verbose \
  --name "$slug-edit" \
  --max-budget-usd 10 \
  > "$run_dir/events.jsonl"
```

### Background long-running edit worker

Use `--bg` when the main agent should launch work and come back later:

```bash
claude \
  --bg \
  --worktree "$slug" \
  --permission-mode acceptEdits \
  --model opus --effort high \
  --name "$slug-edit" \
  "$(cat "$run_dir/prompt.md")"

claude agents --json
```

Add `--tmux` with `--worktree` when you want Claude Code's built-in tmux
handling instead of `claude-rc-spawn`.

Use `--dangerously-skip-permissions` only inside a separate container/VM with a
bounded filesystem, network, and secret set. It is not the default edit-worker
mode.

## Capture and resume

- `--output-format json` emits one JSON object; final text is `.result`, session
  id is `.session_id`.
- `--output-format stream-json --verbose` is better for logs, progress, and
  long-running foreground automation.
- `claude-rc-spawn` saves the prompt under `.agent-runs/<tmux-session>/` and
  pipes tmux output to `tmux.log`.
- `claude agents --json` lists background agents.
- Continue the latest session with `claude --continue`.
- Resume a known session with `claude --resume <session-id>`.
- Use `--fork-session` with resume/continue to branch from prior context.

## Reusable named agents

Drop-in custom agents are in `assets/`:

- `assets/cc-reviewer.md` -> read-only second-opinion reviewer.
- `assets/cc-editor.md` -> edit-capable worker with `isolation: worktree`.

Install them into the repo or globally:

```bash
skill_dir="<directory containing this SKILL.md>"
mkdir -p .claude/agents
cp "$skill_dir"/assets/cc-*.md .claude/agents/

cat "$run_dir/prompt.md" | claude -p \
  --agent cc-reviewer \
  --effort high \
  --permission-mode plan \
  --output-format json
```

Agent files shape persona and tools, but hard permission behavior still comes
from `--permission-mode`, settings, and permission rules. Pair the agent with the
right mode every time.

## Gotchas

- `claude -p` skips the workspace-trust dialog. Only run it in directories you
  trust.
- `--worktree` creates a Git worktree under `.claude/worktrees/<name>` and a
  branch named `worktree-<name>` by default. Non-interactive `-p --worktree`
  runs do not get an exit prompt, so clean up completed worktrees yourself.
- Claude worktrees start from `origin/HEAD` by default. Set `worktree.baseRef` to
  `head` when the worker must include local in-progress branch state.
- `--add-dir` grants file access; it does not copy project configuration or make
  the extra directory the working checkout.
- `--agent` selects a custom agent/persona. It does not by itself make a run
  read-only or safe to edit; use `--permission-mode plan`, `acceptEdits`, or
  `auto` explicitly.
- `bypassPermissions` / `--dangerously-skip-permissions` skips important
  prompts and can write protected project/config areas. Use only in isolated
  environments, preferably without internet access.
- `--max-budget-usd` is a print-mode cap in the current CLI. It is appropriate
  for foreground `claude -p` automation, not a reliable limiter for `--bg`.
- Remote Control requires a full claude.ai login and direct Anthropic API
  access. If `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_API_KEY`, or a non-default
  `ANTHROPIC_BASE_URL` is active, Remote Control can fail before the session
  starts. Prefer `claude-rc-spawn` or explicitly launch with those vars unset.
- `claude remote-control` is server mode; it does not create a local interactive
  prompt. Use it for user-dispatched sessions, and use `claude-rc-spawn` for a
  main-agent-launched task with an injected prompt.
- A persistent server should be supervised by systemd, not kept alive only by
  tmux. Use one service per repo, with distinct `SERVICE_NAME`, `SESSION_NAME`,
  and `SESSION_PREFIX` values such as `claude-rc-skills` / `skills@devbox` /
  `devbox-skills`.
- `StartLimitIntervalSec=0` plus `Restart=always` keeps the server retrying
  after reboot or temporary network/auth trouble. Check the user journal for the
  current claude.ai/code environment URL.
- Remote Control is tied to the local process. For prompted runs, keep the tmux
  session alive; for server mode, keep the systemd service active.
- Background agents are managed with `claude agents`; name them with `--name` so
  the main agent can tell concurrent runs apart.
- For large automation, split maker and checker: run an edit worker, then a fresh
  reviewer against the diff before accepting the result.
