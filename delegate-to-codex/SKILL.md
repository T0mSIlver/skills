---
name: delegate-to-codex
description: Call the OpenAI Codex CLI (`codex exec`) non-interactively to get a second opinion, a code review, or to run it as a subagent that reads/investigates or edits code. Use when you want an independent Codex (GPT-5.5) run — e.g. "get a second opinion from Codex", "have Codex review this", "delegate this to a Codex subagent", or spawn a read-only reviewer vs. an edit-capable worker.
---

# Delegate to Codex (CLI)

Run the `codex` CLI programmatically via `codex exec` (non-interactive) to get a second
opinion, a review, or to delegate a task to a subagent. Two agent configs are provided:
a **read-only reviewer** and an **edit-capable worker**.

These skills assume you are running inside a **sandboxed environment**, so the edit worker
is granted full autonomy (no approval prompts, no inner sandbox) — permission gating is
not needed.

## Prerequisites

- `codex` is on PATH (`codex --version`) and already authenticated (`codex login` or
  `OPENAI_API_KEY` / `CODEX_HOME`).
- `codex exec` is non-interactive by design.

## Step 1 — Commit first (before an edit task)

Before delegating anything that edits files, **commit your current work** so nothing can
be lost and the subagent's changes are isolated and reviewable:

```bash
git add -A && git commit -m "checkpoint before delegating to Codex"
```

Then inspect exactly what the subagent did with `git diff` and revert cleanly if needed.
(Codex also has `codex apply` to apply its produced diff to your tree.)

## Step 2 — Write the prompt to a markdown file

**Always put the prompt in a markdown file and feed it via stdin — do not fight the shell
with an inline string.** This lets you write a long, detailed, well-structured prompt
(headings, code blocks, file lists, acceptance criteria) with zero quoting/escaping
issues. Use your Write tool to create it:

```
/tmp/codex-prompt.md
```

**Invest in the prompt.** A detailed brief gets a dramatically better result than a
one-liner. Include:

- **Context**: what the project is, the relevant files/paths, and how they fit together.
- **Task**: precisely what you want done or reviewed, and what is out of scope.
- **Constraints**: conventions to follow, things not to touch, libraries to prefer.
- **Acceptance criteria**: how the subagent should know it succeeded (tests pass, specific
  behavior), and what to return (a findings list, a diff summary, etc.).

## Step 3 — Model & effort defaults

Always use **GPT-5.5 at high reasoning effort**:

```
-m gpt-5.5 -c model_reasoning_effort="high"
```

`model_reasoning_effort` accepts `minimal, low, medium, high, xhigh`. Use `high` as the
default; drop to `low`/`medium` only for trivial tasks.

## Step 4 — Run one of the two agent configs

The prompt is piped from the file; the trailing `-` tells Codex to read it from stdin.

### Read-only reviewer / second opinion

`-s read-only` lets Codex read files and run read-only commands but **cannot modify the
filesystem** — a hard read-only guarantee.

```bash
cat /tmp/codex-prompt.md | codex exec \
  -m gpt-5.5 -c model_reasoning_effort="high" \
  -s read-only \
  -o /tmp/codex-out.txt \
  -
```

### Edit worker (has the harness edit tool)

In a sandbox, run the edit worker with `--dangerously-bypass-approvals-and-sandbox` — this
flag is intended precisely for externally sandboxed automation, and lets Codex edit files
(via its `apply_patch` tool) and run commands with no restrictions or prompts:

```bash
cat /tmp/codex-prompt.md | codex exec \
  -m gpt-5.5 -c model_reasoning_effort="high" \
  --dangerously-bypass-approvals-and-sandbox \
  -o /tmp/codex-out.txt \
  -
```

Add `-C <dir>` / `--cd <dir>` to set the working root and `--skip-git-repo-check` to run
outside a git repo.

## Capturing the result

- `-o, --output-last-message <FILE>` → writes the agent's final message to a file (best
  for programmatic capture).
- `--json` → streams events as JSONL on stdout (parse the final `agent_message`).
- `--output-schema <FILE>` → force the final response to match a JSON Schema.

## Built-in review mode (alternative)

Codex has a first-class non-interactive reviewer for a pure second opinion on a diff:

```bash
codex exec review --base main -m gpt-5.5 -c model_reasoning_effort="high"
# or: codex exec review --uncommitted   (staged + unstaged + untracked)
# or: codex exec review --commit <sha>
```

## Reusable named profiles (alternative)

Define the two agents once as Codex **profiles** and select them with `-p`. Profiles live
at `$CODEX_HOME/<name>.config.toml` (default `~/.codex/`). Drop-in configs are in `assets/`:

- `assets/reviewer.config.toml` → read-only reviewer (GPT-5.5 high, `read-only`)
- `assets/editor.config.toml` → edit worker (GPT-5.5 high, `danger-full-access`)

```bash
cp assets/reviewer.config.toml "${CODEX_HOME:-$HOME/.codex}/reviewer.config.toml"
cp assets/editor.config.toml   "${CODEX_HOME:-$HOME/.codex}/editor.config.toml"

cat /tmp/codex-prompt.md | codex exec -p reviewer -
cat /tmp/codex-prompt.md | codex exec -p editor -
```

## Notes

- `codex exec` is one-shot. Continue a prior run with `codex exec resume --last` (or by id).
- Persist a session-free run with `--ephemeral`; ignore user config with `--ignore-user-config`.
