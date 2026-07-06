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
commands, and required final output. The brief reaches opencode as the
positional message — inline it with `"$(cat prompt.md)"`. `--file` does NOT
send file contents as the prompt: it only attaches files to a message, and a
non-empty message is still required. If a brief is too large to inline
comfortably, keep a short instruction as the positional and attach the brief —
with the positional BEFORE the flag (see Gotchas for why the order matters):

```bash
opencode run "Follow the attached prompt file exactly." --file prompt.md ...
```

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
  "$(cat "$prompt_file")" \
  < /dev/null \
  > "$run_dir/events.jsonl"
```

The `< /dev/null` is mandatory, not decoration: `opencode run` reads stdin on
startup, and when it is launched from a non-interactive harness (the Claude Code
Bash tool, cron, most orchestrators) stdin is an open, silent pipe/socket that
never sends data and never closes. opencode parks in its event loop waiting for
that stdin, wedging at `init` before it ever creates a session or contacts the
model — the exact "stalls, nothing in events.jsonl" symptom. Redirecting from
`/dev/null` delivers an immediate EOF so the run proceeds. See Gotchas.

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
  "$(cat "$run_dir/prompt.md")" \
  < /dev/null \
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
  A run that is 0 bytes from the very start and whose log stops at `init` (no
  `created id=ses_...` line) is almost always the missing `< /dev/null`
  redirect, not a provider or DB problem — confirm the launch has it before
  investigating anything else.
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

- Missing `< /dev/null` is the top cause of a run that "stalls with an empty
  events.jsonl". `opencode run` reads stdin at startup; under a non-interactive
  harness stdin is an open pipe/socket that never closes, so opencode blocks in
  its event loop (`epoll_wait` on fd 0) waiting for input that never arrives. It
  wedges at `init` — before any session is created or the model is contacted —
  and only the `timeout` wrapper ever ends it. Symptoms: `events.jsonl` 0 bytes
  from the start, `~/.local/share/opencode/log/opencode.log` ends at `init` with
  no `created id=ses_...`, the process idle at ~0% CPU holding fd 0 as a
  connected socket and no outbound TCP. Always redirect `< /dev/null` on every
  `opencode run` launched from the Claude Code Bash tool, cron, or any
  orchestrator. Confirmed by A/B: identical command hangs without the redirect,
  completes with it.
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
- `--file` never carries the prompt. It is an attachment flag ("file(s) to
  attach to message"; `run.ts` declares it `array: true`), and `opencode run`
  still requires a non-empty positional message — `--file` alone dies with
  `You must provide a message or a command`. Worse, yargs array flags greedily
  consume the positionals that follow them, so `--file prompt.md "do X"` —
  and the `--file=prompt.md` form too — swallow the message into the file
  list and die with `File not found: do X`. All three failure modes verified
  on 1.17.13. Safe forms: inline the brief as the positional message
  (`"$(cat prompt.md)"`), or put the message BEFORE the flag:
  `opencode run "Follow the attached prompt file exactly." --file prompt.md`.
  Briefs that could start with a `-` need the inline form quoted as one
  argument (they already are with `"$(cat ...)"`).
- Check `~/.local/share/opencode/log/opencode.log` when a run goes quiet. It is
  one shared log with UTC timestamps; grep for `run=` or `agent=` to distinguish
  "never initialized" from "stalled mid-stream".
- Worktrees do not copy ignored local files. Copy only explicit required files
  into the worker worktree.
