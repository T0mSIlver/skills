---
name: delegate-to-claude-code
description: Call the Claude Code CLI (`claude`) non-interactively or as a background/worktree run to get a second opinion, run a code review, or delegate read-only or edit-capable work. Use for Claude Code subagent-style delegation, `claude -p`, `--bg`, `--worktree`, `--tmux`, plan/read-only reviewers, acceptEdits/auto edit workers, JSON/stream-json capture, resume flows, and gotchas around permission modes, worktree cleanup, agent personas, and `--dangerously-skip-permissions`.
---

# Delegate to Claude Code (CLI)

Run `claude` programmatically for independent investigation, review, or a
delegated worker. Claude Code has strong first-class support for long-running
work: `--worktree`, `--bg`, `claude agents`, `--tmux`, session names, resume,
and print-mode budget caps.

## Prerequisites

- Verify `claude` is on PATH with `claude --version`.
- Verify auth is available with `claude auth login` or `ANTHROPIC_API_KEY`.
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

### Read-only reviewer / second opinion

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

Add `--tmux` with `--worktree` when you want a persistent terminal session you
can attach to and inspect.

Use `--dangerously-skip-permissions` only inside a separate container/VM with a
bounded filesystem, network, and secret set. It is not the default edit-worker
mode.

## Capture and resume

- `--output-format json` emits one JSON object; final text is `.result`, session
  id is `.session_id`.
- `--output-format stream-json --verbose` is better for logs, progress, and
  long-running foreground automation.
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
- Background agents are managed with `claude agents`; name them with `--name` so
  the main agent can tell concurrent runs apart.
- For large automation, split maker and checker: run an edit worker, then a fresh
  reviewer against the diff before accepting the result.
