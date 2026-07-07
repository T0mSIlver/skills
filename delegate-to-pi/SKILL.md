---
name: delegate-to-pi
description: Call the pi coding agent CLI (`pi -p` / `--mode json`) non-interactively to get a second opinion, run a code review, or delegate read-only or edit-capable work to an independent pi run. Use for pi subagent-style delegation, `@file` prompt briefs, JSON event capture, session resume/fork with `--session`/`--session-id`, and harness gotchas around pi having NO permission system or sandbox, stdin EOF hangs, project trust in headless runs, cwd-keyed sessions, and global extensions leaking into delegated runs.
---

# Delegate to pi (CLI)

Run `pi` (the `@earendil-works/pi-coding-agent` CLI) non-interactively for
independent investigation, review, or a delegated worker. pi is deliberately
minimal: it has **no permission system, no sandbox, no plan mode, no built-in
subagents, and no worktree support**. Everything the other harnesses enforce
with permission modes must be enforced here with tool allowlists (`--tools`),
manual Git worktrees, and — for untrusted work — a container/VM boundary.

## Prerequisites

- Verify `pi` is on PATH with `pi --version`.
- Verify a model is actually usable with `pi --list-models`. Only models with
  configured auth appear; on machines without cloud keys the list may be only
  local models (Ollama/llama.cpp), and cloud model flags will exit 1 with
  `No API key found`. Auth comes from `/login` (interactive, stored in
  `~/.pi/agent/auth.json`), env vars, or `--api-key`.
- pi has no `-C`/`--dir` flag. It runs in the process cwd, and sessions are
  stored keyed by cwd. Always `cd` into the target checkout/worktree before
  launching.
- When copying bundled system prompts, resolve `skill_dir` to the directory
  containing this `SKILL.md`; `assets/...` is not relative to the target repo.

## Step 1 - Choose isolation

pi's only built-in restriction mechanism is the tool allowlist. For read-only
review, stay in the current checkout and pass:

```bash
--tools read,grep,find,ls
```

This removes `bash`, `edit`, and `write` from the model entirely (verified: the
model has no way to mutate files or run commands). It is an agent-level
allowlist, NOT an OS sandbox — loaded extensions still execute as arbitrary
Node code, and the pi process keeps full user permissions.

For edit work, create a branch/worktree yourself; pi will not:

```bash
slug="pi-$(date +%Y%m%d-%H%M%S)"
branch="agent/pi/$slug"
worktree="../$(basename "$PWD")-$slug"
git worktree add -b "$branch" "$worktree" HEAD
mkdir -p "$worktree/.agent-runs/$slug"
```

If the worker needs uncommitted local changes, apply an explicit patch in the
worktree or commit only the intentional prerequisite changes. Do not checkpoint
unrelated user work with `git add -A`.

An edit worker gets `bash` with your full user account: it can touch files
outside the worktree, hit the network, and read anything you can read. For
untrusted repos or unattended long runs, run pi inside a container/VM with only
the workspace mounted (see pi's `docs/containerization.md`). A worktree alone is
not a security boundary.

## Step 2 - Write a prompt file

Write the full brief to the run directory. For read-only runs this can be under
`/tmp`; for edit runs keep it inside the worker worktree:

```text
/tmp/pi-$slug/prompt.md
$worktree/.agent-runs/$slug/prompt.md
```

Include context, exact task, constraints, acceptance criteria, verification
commands, and required final output. pi takes the brief either as an `@file`
argument (contents are included in the message) or via piped stdin, which
print mode merges into the initial prompt:

```bash
pi -p @prompt.md "Follow the brief above exactly."
pi -p "Follow this brief exactly." < prompt.md   # also works; see stdin gotcha
```

## Step 3 - Pick model and thinking level

Do not assume a default: `defaultProvider`/`defaultModel` come from
`~/.pi/agent/settings.json` and may point at a small local model. Pin the model
explicitly for delegated work and check it is authenticated first:

```bash
pi --list-models
--model anthropic/claude-opus-4-8 --thinking high
--model sonnet:high                # pattern + ":<thinking>" shorthand
```

`--thinking` levels: `off`, `minimal`, `low`, `medium`, `high`, `xhigh`. Use
high for demanding review/edit work, lower tiers for mechanical scans. Do not
hard-code a model when the user asks for a specific cost/latency profile.

## Step 4 - Launch the run

### Read-only reviewer / second opinion

```bash
run_dir="/tmp/pi-$slug"
mkdir -p "$run_dir"
skill_dir="<directory containing this SKILL.md>"

cd "$repo" && timeout --signal=TERM 2700 pi \
  --mode json --no-session \
  --tools read,grep,find,ls \
  --append-system-prompt "$skill_dir/assets/reviewer-system.md" \
  --model anthropic/claude-opus-4-8 --thinking high \
  @"$run_dir/prompt.md" "Follow the brief above exactly." \
  < /dev/null \
  > "$run_dir/events.jsonl"
```

The `< /dev/null` is mandatory: in print/JSON mode pi reads piped stdin and
merges it into the prompt, so it **blocks until stdin reaches EOF**. Under a
non-interactive harness (the Claude Code Bash tool, cron, orchestrators) stdin
is an open pipe that never closes, and the run hangs forever before contacting
the model (verified by A/B test). Either redirect `< /dev/null` or pipe the
prompt itself so EOF arrives.

### Edit worker

```bash
run_dir="$worktree/.agent-runs/$slug"

cd "$worktree" && timeout --signal=TERM 2700 pi \
  --mode json \
  --session-id "$(uuidgen)" --name "$slug-edit" \
  --append-system-prompt "$skill_dir/assets/editor-system.md" \
  --model anthropic/claude-opus-4-8 --thinking high \
  @"$run_dir/prompt.md" "Follow the brief above exactly." \
  < /dev/null \
  > "$run_dir/events.jsonl"
```

Record the `--session-id` value in the run state; it is the resume handle.
There is no approval step of any kind: the worker edits and runs shell commands
immediately. Scope the brief tightly and review the diff afterwards.

The `timeout` wrapper is the outer safety net for silent provider stalls; pi's
own retry (3 attempts, exponential backoff) only covers surfaced errors.

## Step 5 - Harvest and review

- First line of `events.jsonl` is the session header:
  `jq -r 'select(.type=="session") | .id' events.jsonl | head -1`.
- Final text: last `message_end` event with `role: "assistant"`, or use `-p`
  instead of `--mode json` when only the final text matters.
- Check for failure: in `--mode json`, an assistant `stopReason` of `"error"`
  or `"aborted"` can still exit 0 — grep the events, do not trust the exit code
  alone. Plain `-p` does exit 1 and prints the error to stderr.
- Inspect the worktree diff with `git -C "$worktree" diff`.
- Run a fresh read-only reviewer over the diff before merging or opening a PR.

## Resume and fork

Sessions save to `~/.pi/agent/sessions/`, keyed by cwd, unless `--no-session`.
Run resume commands from the same directory as the original run:

```bash
pi -p -c "Address the reviewer findings and rerun verification." < /dev/null
pi -p --session <partial-uuid-or-path> "Continue: fix the remaining gaps." < /dev/null
pi -p --fork <partial-uuid-or-path> "Explore the alternative fix instead." < /dev/null
pi -p --session-id <recorded-id> "Continue the delegated task." < /dev/null
```

- `--session-id` (exact project-local id, created if missing) is the
  automation-friendly handle; `--session` accepts partial UUIDs and file paths.
- `--fork` cannot be combined with `--session`, `--continue`, `--resume`, or
  `--no-session`; pi exits 1 on the conflict.
- Do not use `--no-session` for a run you may need to resume.

## Bundled system prompts

pi has no agent/profile files; persona comes from the system prompt.
`--append-system-prompt <path>` loads file contents (verified):

- `assets/reviewer-system.md` -> read-only second-opinion reviewer. Pair it
  with `--tools read,grep,find,ls`; the prompt alone enforces nothing.
- `assets/editor-system.md` -> scoped edit worker.

Project-level alternatives: `.pi/APPEND_SYSTEM.md` appends and `.pi/SYSTEM.md`
replaces the default system prompt — but both are project resources gated by
project trust (below).

## Gotchas

- **No permission system, by design.** There is no permission mode, prompt, or
  sandbox to fall back on; "YOLO by default" is the documented stance. The only
  in-process control is which tools exist (`--tools`, `--exclude-tools`,
  `--no-tools`). Restriction beyond that must come from containers/VMs.
- **Missing `< /dev/null` hangs the run.** Print/JSON mode waits for stdin EOF
  to merge piped input into the prompt. An orchestrator's open stdin pipe means
  pi blocks forever before creating a session or contacting the model. Symptom:
  no output at all, process idle. Redirect `< /dev/null` on every delegated run.
- **Project trust silently drops project resources in headless runs.**
  `-p`/`--mode json` never show a trust prompt. With no saved decision in
  `~/.pi/agent/trust.json` and the default `defaultProjectTrust: "ask"`, the
  run silently ignores `.pi/settings.json`, `.pi` extensions/skills/system
  prompts, and project `.agents/skills`. Pass `--approve`/`-a` to trust the
  project for one run (only for repos you already trust — it executes project
  extension code), or `--no-approve`/`-na` to pin the ignore behavior.
- **Global extensions leak into delegated runs.** Everything in
  `~/.pi/agent/settings.json` `packages`/`extensions` (memory, todo, web tools,
  permission gates) loads into every run, changing the tool surface and
  spending context. `--no-extensions` gives a vanilla run — but it also removes
  extension-registered custom providers, which can turn the configured default
  model into `No API key found` (exit 1). When using `--no-extensions`, pin a
  `--model` that exists without extensions.
- **Extensions cannot ask questions in `-p`/`--mode json`.** `ctx.hasUI` is
  false and UI methods are no-ops, so interactive extension tools (e.g.
  `ask_question`-style) cannot reach a human. Deny-rules in permission-gate
  extensions still work (verified: a denied write returned an error to the
  model instead of hanging). Disable known-interactive tools with
  `--exclude-tools` if the model tends to call them.
- **`--session <id>` can block on a cross-project match.** If the partial id
  resolves to a session from a different directory, pi asks on stdin whether to
  fork it into the current project — which wedges a headless run. Prefer exact
  `--session-id`, a full session file path, or running from the original cwd.
- **Sessions are keyed by cwd.** `-c` continues the most recent session *for
  the current directory*. Resuming a worktree run requires `cd` back into that
  worktree (or the recorded session file path).
- **Exit codes differ by mode.** `-p` exits 1 and prints to stderr when the
  final assistant message errored/aborted; `--mode json` only exits nonzero on
  thrown exceptions, so parse events for `stopReason` before declaring success.
- **No background bash or MCP.** Long-running servers/REPLs need tmux (the
  upstream-recommended pattern); external integrations are plain CLI tools on
  PATH rather than MCP servers.
- **Startup network calls.** pi checks pi.dev for updates at startup; pass
  `--offline` (or `PI_OFFLINE=1`) for hermetic/CI runs.
- Worktrees do not include ignored local files. Copy only explicit
  prerequisites such as `.env.local`, never broad secret directories.
