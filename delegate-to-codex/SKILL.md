---
name: delegate-to-codex
description: Call the OpenAI Codex CLI (`codex exec`) non-interactively to get a second opinion, run a code review, or delegate read-only or edit-capable work to an independent Codex run. Use for Codex CLI subagent-style delegation, long-running worker runs, worktree-isolated edits, machine-readable JSONL output, `codex exec review`, resume flows, and harness gotchas around sandboxing, profiles, and `--dangerously-bypass-approvals-and-sandbox`.
---

# Delegate to Codex (CLI)

Run `codex exec` non-interactively for independent investigation, review, or a
delegated worker. For edit tasks, isolate the worker in a branch/worktree and
capture enough state to poll, resume, review, and clean up.

## Prerequisites

- Verify `codex` is on PATH with `codex --version`.
- Verify auth is available with `codex login`, ChatGPT auth, or a scoped
  `CODEX_API_KEY`/`OPENAI_API_KEY` setup.
- Run inside a Git repository unless you intentionally pass
  `--skip-git-repo-check`.
- When copying bundled configs, resolve `skill_dir` to the directory containing
  this `SKILL.md`; `assets/...` is not relative to the target repo.

## Step 1 - Choose isolation

For read-only review, stay in the current checkout and use `-s read-only`.

For edit work, prefer a new worktree. This keeps long runs from modifying the
main agent's files and makes the resulting diff easy to inspect or discard.

```bash
slug="codex-$(date +%Y%m%d-%H%M%S)"
branch="agent/codex/$slug"
worktree="../$(basename "$PWD")-$slug"
git worktree add -b "$branch" "$worktree" HEAD
mkdir -p "$worktree/.agent-runs/$slug"
```

If the worker needs uncommitted local changes, either commit only the intentional
prerequisite changes first or create an explicit patch and apply it inside the
worktree. Do not use a blind `git add -A` checkpoint when unrelated user work is
present.

## Step 2 - Write a prompt file

Write the full brief to a markdown file under the run directory. For read-only
runs this can be under `/tmp`; for edit runs keep it inside the worker worktree:

```text
/tmp/codex-$slug/prompt.md
$worktree/.agent-runs/$slug/prompt.md
```

Include:

- Context: relevant files, commands, docs, and current branch/base.
- Task: exactly what to do or review, plus what is out of scope.
- Constraints: style, libraries, files not to touch, branch/worktree rules.
- Acceptance criteria: tests/builds to run and what "done" means.
- Output contract: summary, changed files, verification evidence, open risks.

## Step 3 - Pick model and effort

Use GPT-5.5 high for demanding work:

```bash
-m gpt-5.5 -c model_reasoning_effort='"high"'
```

Use medium or low only for small scans or mechanical tasks. Do not hard-code this
when the user explicitly asks for a different model or cost/latency profile.

## Step 4 - Launch the run

### Read-only reviewer / second opinion

```bash
run_dir="/tmp/codex-$slug"
prompt_file="$run_dir/prompt.md"
mkdir -p "$run_dir"

codex exec \
  -C "$PWD" \
  -m gpt-5.5 -c model_reasoning_effort='"high"' \
  -s read-only \
  --json \
  -o "$run_dir/final.md" \
  - < "$prompt_file" \
  > "$run_dir/events.jsonl"
```

### Edit worker

Use `workspace-write` with no prompts as the default unattended local worker. It
can edit within the worktree while keeping Codex's sandbox boundary.

```bash
run_dir="$worktree/.agent-runs/$slug"

codex exec \
  -C "$worktree" \
  -m gpt-5.5 -c model_reasoning_effort='"high"' \
  --sandbox workspace-write \
  -a never \
  --json \
  -o "$run_dir/final.md" \
  - < "$run_dir/prompt.md" \
  > "$run_dir/events.jsonl"
```

Use `--dangerously-bypass-approvals-and-sandbox` only inside a separate
container/VM/CI runner whose filesystem, network, and secrets are already
bounded. A worktree alone is not a security sandbox.

## Step 5 - Harvest and review

- Parse `thread.started` in `events.jsonl` for the session id.
- Read `final.md` for the final answer.
- Inspect the worktree diff with `git -C "$worktree" diff`.
- Run `codex exec review --base <base>` or a separate read-only reviewer before
  merging, cherry-picking, or opening a PR.

## Resume

Continue a non-ephemeral session:

```bash
codex exec resume --last "Continue from the previous result and address only the remaining gaps."
codex exec resume <session-id> "Address the reviewer findings and rerun verification."
```

Do not use `--ephemeral` for a run you may need to resume; it avoids persisting
session rollout files.

## Built-in review mode

For pure review, prefer the first-class review command:

```bash
codex exec review --base main -m gpt-5.5 -c model_reasoning_effort='"high"'
codex exec review --uncommitted
codex exec review --commit <sha>
```

## Reusable named profiles

Profiles live at `$CODEX_HOME/<name>.config.toml` (default `~/.codex/`). Drop-in
configs are in `assets/`:

- `assets/reviewer.config.toml` -> read-only reviewer.
- `assets/editor.config.toml` -> workspace-write edit worker with no prompts.

```bash
skill_dir="<directory containing this SKILL.md>"
cp "$skill_dir/assets/reviewer.config.toml" "${CODEX_HOME:-$HOME/.codex}/reviewer.config.toml"
cp "$skill_dir/assets/editor.config.toml"   "${CODEX_HOME:-$HOME/.codex}/editor.config.toml"

codex exec -C "$worktree" -p reviewer - < "$run_dir/prompt.md"
codex exec -C "$worktree" -p editor   - < "$run_dir/prompt.md"
```

## Gotchas

- `codex exec` reads the full prompt from stdin when you pass `-`. If you also
  pass a prompt argument, piped stdin becomes extra context instead of the
  instruction.
- `-p` selects a Codex config profile, not a custom subagent. Custom Codex
  subagents are TOML files under `.codex/agents/` or `~/.codex/agents/`.
- `--json` writes JSONL events to stdout. If you also want the final answer as a
  simple file, pass `-o <file>`.
- `-s read-only` is a hard filesystem boundary; commands that write caches,
  build artifacts, or temp files inside the repo can fail.
- `workspace-write -a never` is usually enough for unattended edit workers.
  Reach for danger-full-access only after an external sandbox is already in
  place.
- Worktrees do not include ignored local files by default. Copy only explicit
  prerequisites such as `.env.local`, and never copy broad secret directories.
- `codex apply` applies the latest diff produced by a Codex agent to the current
  tree. Check `pwd`, branch, and `git status` before using it.
