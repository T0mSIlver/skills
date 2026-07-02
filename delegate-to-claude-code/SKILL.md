---
name: delegate-to-claude-code
description: Call the Claude Code CLI (`claude`) non-interactively to get a second opinion, a code review, or to run it as a subagent that reads/investigates or edits code. Use when you want an independent Claude Code run — e.g. "get a second opinion from Claude Code", "have Claude Code review this", "delegate this to a Claude Code subagent", or spawn a read-only reviewer vs. an edit-capable worker.
---

# Delegate to Claude Code (CLI)

Run the `claude` CLI programmatically (headless / `-p` print mode) to get a second
opinion, a review, or to delegate a task to a subagent. Two agent configs are provided:
a **read-only reviewer** and an **edit-capable worker**.

## Prerequisites

- `claude` is on PATH (`claude --version`). Authenticate once with `claude auth` (or set
  `ANTHROPIC_API_KEY`). In a non-interactive/sandbox context, auth must already be set up.
- Run from inside the target repo, or pass `--add-dir <path>` to grant access.

## Model & effort defaults

Pick the model with `--model` and reasoning depth with `--effort`:

| Task | Flags |
|------|-------|
| **Default** (reviews, non-trivial work) | `--model opus --effort high` |
| **Very very easy** tasks (trivial lookups, mechanical edits) | `--model sonnet --effort low` |

`opus` resolves to the latest Opus (`claude-opus-4-8`); `sonnet` to the latest Sonnet
(`claude-sonnet-5`). `--effort` accepts `low, medium, high, xhigh, max`.

## The two agent configs

Permission mode is what makes an agent read-only vs. edit-capable:

- **Read-only reviewer** → `--permission-mode plan`. The harness blocks every mutating
  action (Edit, Write, mutating Bash), so the run can read/search/inspect but **cannot
  change files** — a hard guarantee, and fully non-interactive.
- **Edit worker** → `--permission-mode acceptEdits`. Edit/Write are auto-accepted so the
  run applies changes without prompting.

### Read-only reviewer / second opinion

```bash
claude -p "Review the changes on this branch for correctness bugs. Report findings only." \
  --model opus --effort high \
  --permission-mode plan \
  --output-format json \
  --add-dir .
```

### Edit worker (has the harness edit tool)

```bash
claude -p "Fix the failing test in tests/test_auth.py and make it pass." \
  --model opus --effort high \
  --permission-mode acceptEdits \
  --output-format json \
  --add-dir .
```

For a fully autonomous edit run in a trusted sandbox (also auto-runs Bash such as tests),
add `--dangerously-skip-permissions` instead of `acceptEdits`. Only do this in a sandbox
with no untrusted input — it bypasses **all** permission checks.

## Capturing the result

- `--output-format json` → one JSON object; the reply is the `.result` field. Extract with
  `claude -p ... --output-format json | jq -r '.result'`.
- `--output-format text` (default) → raw text on stdout.
- `--json-schema '<schema>'` → force the final message to match a JSON schema (structured
  output). Combine with `--output-format json`.
- Prompt via stdin instead of an argument: `echo "$PROMPT" | claude -p --model opus ...`.

## Restricting tools (optional)

To hand the subagent a narrower toolset, use `--tools` (built-in set) or the
allow/deny lists — independent of permission mode:

```bash
# read-only, search-only toolset
claude -p "$PROMPT" --model opus --effort high --permission-mode plan \
  --tools "Read,Grep,Glob,WebSearch,WebFetch"

# scope Bash to safe read commands while still allowing edits
claude -p "$PROMPT" --model opus --effort high --permission-mode acceptEdits \
  --allowedTools "Read Edit Write Grep Glob Bash(git diff:*) Bash(git log:*) Bash(rg:*)"
```

## Reusable named agents (alternative)

Instead of flags, define personas once as agent files and select them with `--agent`.
Drop-in configs are in `assets/`:

- `assets/cc-reviewer.md` → read-only second-opinion reviewer
- `assets/cc-editor.md` → edit-capable worker

Install them into the repo (or `~/.claude/agents/` for global) and invoke:

```bash
mkdir -p .claude/agents && cp assets/cc-*.md .claude/agents/
claude -p "$PROMPT" --agent cc-reviewer --effort high --permission-mode plan
```

You can also pass agents inline without files:

```bash
claude -p "$PROMPT" --permission-mode plan --effort high \
  --agents '{"cc-reviewer":{"description":"Read-only reviewer","prompt":"You are a meticulous read-only code reviewer. Investigate and report findings; never modify files.","tools":["Read","Grep","Glob","WebSearch"],"model":"opus"}}' \
  --agent cc-reviewer
```

## Notes

- `claude -p` skips the workspace-trust dialog — only run it in directories you trust.
- Print mode is one-shot. To continue a prior run add `--continue` (most recent) or
  `--resume <session-id>`; capture the id from `--output-format json`'s `.session_id`.
- Use `--max-budget-usd <amount>` to cap spend on an autonomous run.
