---
name: delegate-to-claude-code
description: Call the Claude Code CLI (`claude`) non-interactively to get a second opinion, a code review, or to run it as a subagent that reads/investigates or edits code. Use when you want an independent Claude Code run — e.g. "get a second opinion from Claude Code", "have Claude Code review this", "delegate this to a Claude Code subagent", or spawn a read-only reviewer vs. an edit-capable worker.
---

# Delegate to Claude Code (CLI)

Run the `claude` CLI programmatically (headless / `-p` print mode) to get a second
opinion, a review, or to delegate a task to a subagent. Two agent configs are provided:
a **read-only reviewer** and an **edit-capable worker**.

These skills assume you are running inside a **sandboxed environment**, so the edit worker
is granted full autonomy (no permission prompts) — permission gating is not needed.

## Prerequisites

- `claude` is on PATH (`claude --version`) and already authenticated (`claude auth` or
  `ANTHROPIC_API_KEY`).
- Run from inside the target repo, or pass `--add-dir <path>` to grant access.

## Step 1 — Commit first (before an edit task)

Before delegating anything that edits files, **commit your current work** so nothing can
be lost and the subagent's changes are isolated and reviewable:

```bash
git add -A && git commit -m "checkpoint before delegating to Claude Code"
```

Then you can inspect exactly what the subagent did with `git diff` and revert cleanly if
needed. (Harmless to do before a read-only review too.)

## Step 2 — Write the prompt to a markdown file

**Always put the prompt in a markdown file and feed it via stdin — do not fight the shell
with an inline string.** This lets you write a long, detailed, well-structured prompt
(headings, code blocks, file lists, acceptance criteria) with zero quoting/escaping
issues. Use your Write tool to create it:

```
/tmp/cc-prompt.md
```

**Invest in the prompt.** A detailed brief gets a dramatically better result than a
one-liner. Include:

- **Context**: what the project is, the relevant files/paths, and how they fit together.
- **Task**: precisely what you want done or reviewed, and what is out of scope.
- **Constraints**: conventions to follow, things not to touch, libraries to prefer.
- **Acceptance criteria**: how the subagent should know it succeeded (tests pass, specific
  behavior), and what to return (a findings list, a diff summary, etc.).

## Step 3 — Model & effort defaults

Pick the model with `--model` and reasoning depth with `--effort`:

| Task | Flags |
|------|-------|
| **Default** (reviews, non-trivial work) | `--model opus --effort high` |
| **Very very easy** tasks (trivial lookups, mechanical edits) | `--model sonnet --effort low` |

`opus` resolves to the latest Opus (`claude-opus-4-8`); `sonnet` to the latest Sonnet
(`claude-sonnet-5`). `--effort` accepts `low, medium, high, xhigh, max`.

## Step 4 — Run one of the two agent configs

The prompt comes from the file over stdin; no prompt argument is passed.

### Read-only reviewer / second opinion

`--permission-mode plan` blocks every mutating action (Edit, Write, mutating Bash), so the
run can read/search/inspect but **cannot change files** — a hard read-only guarantee.

```bash
cat /tmp/cc-prompt.md | claude -p \
  --model opus --effort high \
  --permission-mode plan \
  --output-format json \
  --add-dir .
```

### Edit worker (has the harness edit tool)

In a sandbox, run the edit worker fully autonomously with `--dangerously-skip-permissions`
so it applies edits and runs Bash (e.g. tests) without any prompts:

```bash
cat /tmp/cc-prompt.md | claude -p \
  --model opus --effort high \
  --dangerously-skip-permissions \
  --output-format json \
  --add-dir .
```

## Capturing the result

- `--output-format json` → one JSON object; the reply is `.result`. Extract with
  `... | jq -r '.result'`. The session id is `.session_id`.
- `--output-format text` (default) → raw text on stdout.
- `--json-schema '<schema>'` → force the final message to match a JSON schema (structured
  output). Combine with `--output-format json`.

## Reusable named agents (alternative)

Instead of flags, define personas once as agent files and select them with `--agent`.
Drop-in configs are in `assets/`:

- `assets/cc-reviewer.md` → read-only second-opinion reviewer
- `assets/cc-editor.md` → edit-capable worker

Install them into the repo (or `~/.claude/agents/` for global) and invoke:

```bash
mkdir -p .claude/agents && cp assets/cc-*.md .claude/agents/
cat /tmp/cc-prompt.md | claude -p --agent cc-reviewer --effort high --permission-mode plan
```

## Notes

- `claude -p` skips the workspace-trust dialog — only run it in directories you trust.
- Print mode is one-shot. To continue a prior run add `--continue` (most recent) or
  `--resume <session-id>`.
- Use `--max-budget-usd <amount>` to cap spend on an autonomous run.
