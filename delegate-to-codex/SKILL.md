---
name: delegate-to-codex
description: Call the OpenAI Codex CLI (`codex exec`) non-interactively to get a second opinion, a code review, or to run it as a subagent that reads/investigates or edits code. Use when you want an independent Codex (GPT-5.5) run — e.g. "get a second opinion from Codex", "have Codex review this", "delegate this to a Codex subagent", or spawn a read-only reviewer vs. an edit-capable worker.
---

# Delegate to Codex (CLI)

Run the `codex` CLI programmatically via `codex exec` (non-interactive) to get a second
opinion, a review, or to delegate a task to a subagent. Two agent configs are provided:
a **read-only reviewer** and an **edit-capable worker**.

## Prerequisites

- `codex` is on PATH (`codex --version`). Authenticate once with `codex login` (or set
  `OPENAI_API_KEY` / `CODEX_HOME`). In a non-interactive/sandbox context, auth must
  already be set up.
- `codex exec` runs without approval prompts by design; the **sandbox mode** is what
  gates file writes (see below).

## Model & effort defaults

Always use **GPT-5.5 at high reasoning effort**:

```
-m gpt-5.5 -c model_reasoning_effort="high"
```

`model_reasoning_effort` accepts `minimal, low, medium, high, xhigh`. Use `high` as the
default here; drop to `low`/`medium` only for trivial tasks.

## The two agent configs

The sandbox mode (`-s` / `--sandbox`) makes a run read-only vs. edit-capable:

- **Read-only reviewer** → `-s read-only`. Codex can read files and run read-only
  commands but **cannot modify the filesystem**.
- **Edit worker** → `-s workspace-write`. Codex can edit files within the workspace
  (via its `apply_patch` edit tool) while system dirs stay protected.

### Read-only reviewer / second opinion

```bash
codex exec -m gpt-5.5 -c model_reasoning_effort="high" \
  -s read-only \
  "Review the changes on this branch for correctness bugs. Report findings only." \
  -o /tmp/codex-review.txt
```

### Edit worker (has the harness edit tool)

```bash
codex exec -m gpt-5.5 -c model_reasoning_effort="high" \
  -s workspace-write \
  "Fix the failing test in tests/test_auth.py and make it pass."
```

Add `-C <dir>` / `--cd <dir>` to set the working root, `--add-dir <dir>` to make extra
directories writable, and `--skip-git-repo-check` to run outside a git repo.

## Capturing the result

- `-o, --output-last-message <FILE>` → writes the agent's final message to a file (best
  for programmatic capture).
- `--json` → streams events as JSONL on stdout (parse the final `agent_message`).
- `--output-schema <FILE>` → force the final response to match a JSON Schema (structured
  output).
- Prompt via stdin: `echo "$PROMPT" | codex exec -m gpt-5.5 -s read-only -`.

## Built-in review mode (alternative)

Codex has a first-class non-interactive reviewer. Handy for a pure second opinion on a diff:

```bash
codex exec review --base main -m gpt-5.5 -c model_reasoning_effort="high"
# or: codex exec review --uncommitted   (staged + unstaged + untracked)
# or: codex exec review --commit <sha>
```

## Reusable named profiles (alternative)

Instead of repeating flags, define the two agents once as Codex **profiles** and select
them with `-p`. Profiles live at `$CODEX_HOME/<name>.config.toml` (default `~/.codex/`).
Drop-in configs are in `assets/`:

- `assets/reviewer.config.toml` → read-only reviewer (GPT-5.5 high, `read-only`)
- `assets/editor.config.toml` → edit worker (GPT-5.5 high, `workspace-write`)

Install and invoke:

```bash
cp assets/reviewer.config.toml "${CODEX_HOME:-$HOME/.codex}/reviewer.config.toml"
cp assets/editor.config.toml   "${CODEX_HOME:-$HOME/.codex}/editor.config.toml"

codex exec -p reviewer "Review this branch and report bugs only."
codex exec -p editor   "Implement the TODO in src/parser.rs."
```

## Notes

- `codex exec` is one-shot. Continue a prior run with `codex exec resume --last` (or by id).
- `sandbox_mode`/`-s` also has `danger-full-access` (no filesystem or network restrictions)
  and the `--dangerously-bypass-approvals-and-sandbox` flag — only for externally sandboxed
  environments. Prefer `read-only`/`workspace-write`.
- Persist a session-free run with `--ephemeral`; ignore user config with `--ignore-user-config`.
