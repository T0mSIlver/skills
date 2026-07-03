---
name: delegate-to-opencode
description: "Call the opencode CLI (`opencode run`) non-interactively to get a second opinion, run a code review, or delegate read-only or edit-capable work to an independent opencode run. Use for GLM-5.2/opencode harness delegation, primary/all agent configs with edit permissions, worktree-isolated edit workers, JSON event capture, session resume/fork flows, and gotchas around `mode: subagent`, `--auto`, prompt files, and `--dir`."
---

# Delegate to opencode (CLI)

Run `opencode run` non-interactively for independent investigation, review, or a
delegated worker. opencode does not create Git worktrees for you, so create the
worktree yourself before launching edit workers.

## Prerequisites

- Verify `opencode` is on PATH with `opencode --version`.
- Verify the provider is configured with `opencode auth login`.
- Run from the target repo, or pass `--dir <path>`.
- When copying bundled agents, resolve `skill_dir` to the directory containing
  this `SKILL.md`; `assets/...` is not relative to the target repo.

## Step 1 - Choose isolation

For read-only review, stay in the current checkout with an agent that denies
`edit`.

For edit work, create a branch/worktree first:

```bash
slug="opencode-$(date +%Y%m%d-%H%M%S)"
branch="agent/opencode/$slug"
worktree="../$(basename "$PWD")-$slug"
skill_dir="<directory containing this SKILL.md>"
git worktree add -b "$branch" "$worktree" HEAD
mkdir -p "$worktree/.agent-runs/$slug" "$worktree/.opencode/agents"
cp "$skill_dir/assets/reviewer.md" "$skill_dir/assets/editor.md" "$worktree/.opencode/agents/"
```

If the worker needs uncommitted local changes, apply an explicit patch in the
worktree or commit only the intentional prerequisite changes. Do not checkpoint
unrelated user work with `git add -A`.

## Step 2 - Write a prompt file

Write the full brief to the run directory. For read-only runs this can be under
`/tmp`; for edit runs keep it inside the worker worktree:

```text
/tmp/opencode-$slug/prompt.md
$worktree/.agent-runs/$slug/prompt.md
```

Include context, exact task, constraints, acceptance criteria, verification
commands, and required final output. Use `--file prompt.md` by itself for long
briefs, or inline `"$(cat prompt.md)"` only for prompts safely under shell
argument limits.

## Step 3 - Model default

Use GLM-5.2 unless the user asks otherwise:

```bash
-m zai-coding-plan/glm-5.2
```

Verify the exact provider slug with:

```bash
opencode models | grep glm-5.2
```

Do not hard-code `temperature` for GLM unless a project has measured a better
setting. Let opencode and the provider apply model-specific defaults.

## Step 4 - Install direct-run agents

The supplied agents are `mode: all` so they can be launched directly with
`opencode run --agent ...` and also used as subagents by other opencode agents.
This matters: `mode: subagent` cannot be launched directly with `opencode run
--agent`; opencode warns and falls back to the default agent.

Project-local install:

```bash
skill_dir="<directory containing this SKILL.md>"
mkdir -p .opencode/agents
cp "$skill_dir/assets/reviewer.md" "$skill_dir/assets/editor.md" .opencode/agents/
opencode agent list | grep -E '^(reviewer|editor) \((all|primary)\)'
```

Use `~/.config/opencode/agents/` for global install. The markdown file name
becomes the agent name, so run `opencode agent list` from the repo root after
copying.

## Step 5 - Launch the run

### Read-only reviewer / second opinion

```bash
run_dir="/tmp/opencode-$slug"
prompt_file="$run_dir/prompt.md"
mkdir -p "$run_dir"

timeout --signal=TERM 2700 opencode run \
  --dir "$PWD" \
  --agent reviewer \
  -m zai-coding-plan/glm-5.2 \
  --format json \
  --title "$slug-review" \
  --auto \
  --file "$prompt_file" \
  > "$run_dir/events.jsonl"
```

### Edit worker

```bash
run_dir="$worktree/.agent-runs/$slug"

timeout --signal=TERM 2700 opencode run \
  --dir "$worktree" \
  --agent editor \
  -m zai-coding-plan/glm-5.2 \
  --format json \
  --title "$slug-edit" \
  --auto \
  --file "$run_dir/prompt.md" \
  > "$run_dir/events.jsonl"
```

`--auto` auto-approves actions that would otherwise ask; explicit `deny` rules
still hold. Keep destructive or out-of-scope tools denied in the agent config.

The `timeout` wrapper matters because opencode has no stream timeout: explicit
provider overload errors are retried, but silent provider stalls can otherwise
wait forever. Treat timeout exit as a clean failure for the orchestrator to
kill, stagger, or relaunch.

Run at most two concurrent opencode instances per machine. Stagger additional
runs; a third process can block before its first log entry on the shared
SQLite/WAL state under `~/.local/share/opencode/opencode.db`.

## Capture, resume, and fork

- `--format json` emits raw JSON events. Parse the final text event and capture
  the `sessionID`.
- During a healthy `--format json` run, `events.jsonl` streams continuously. If
  it is still 0 bytes after about 5 minutes, or its mtime is stale for more
  than 10 minutes, assume the run is hung; kill and relaunch instead of waiting.
- `opencode session list` shows saved sessions.
- Continue the last session with `opencode run --continue "..."`.
- Continue a specific session with `opencode run --session <id> "..."`.
- Add `--fork` with `--continue` or `--session` to branch the conversation
  without mutating the original session.
- Export a transcript with `opencode export <sessionID>`.

## Inline config alternative

Instead of markdown files, declare the agents in `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "reviewer": {
      "description": "Read-only second-opinion reviewer",
      "mode": "all",
      "model": "zai-coding-plan/glm-5.2",
      "permission": { "edit": "deny", "bash": "allow", "webfetch": "allow" }
    },
    "editor": {
      "description": "Edit-capable worker",
      "mode": "all",
      "model": "zai-coding-plan/glm-5.2",
      "permission": { "edit": "allow", "bash": "allow", "webfetch": "allow" }
    }
  }
}
```

## Gotchas

- `mode: subagent` plus `opencode run --agent <name>` is a trap: opencode falls
  back to the default primary agent, so your read-only/edit permissions may not
  be active. Use `mode: all` or `mode: primary` for direct-run agents.
- `--auto` is not the same as "allow everything"; explicit `deny` rules still
  block. This is good for reviewers: `edit: deny` holds under `--auto`.
- Hard-coded sampling settings are easy to overfit. For GLM-5.2, omit
  `temperature` by default and tune only with evidence from the target workload.
- Agent permissions merge with global/project defaults. Verify with
  `opencode agent list` after installing or changing agents.
- `opencode agent list` in current CLI versions prints text; do not assume a
  `--format json` flag exists.
- `--dir` is local for normal runs, but when using `--attach` it is a path on
  the remote opencode server.
- opencode has session resume/fork controls but no native worktree creation
  flag. Create and clean up Git worktrees yourself.
- In opencode 1.17.13, combining `--file prompt.md` with a positional message
  makes the CLI treat the message as another file path and fail with `File not
  found: <message text>`. Use `--file` with no positional message, or inline
  `"$(cat prompt.md)"` for prompts safely under argv limits.
- Check `~/.local/share/opencode/log/opencode.log` when a run goes quiet. It is
  one shared log with UTC timestamps; grep for `run=` or `agent=` to distinguish
  "never initialized" from "stalled mid-stream".
- Worktrees do not copy ignored local files. Copy only explicit required files
  into the worker worktree.
