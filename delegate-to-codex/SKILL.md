---
name: delegate-to-codex
description: Call the OpenAI Codex CLI (`codex exec`) non-interactively to get a second opinion, run a code review, or delegate read-only or edit-capable work to an independent Codex run. Use for Codex CLI subagent-style delegation, long-running worker runs, worktree-isolated edits, machine-readable JSONL output, resume flows, and harness gotchas around stdin and sandboxing.
compatibility: Requires the OpenAI Codex CLI (codex) installed and authenticated.
---

# Delegate to Codex (CLI)

Run `codex exec` non-interactively for a second opinion, review, or a delegated
edit worker. Model default: `gpt-5.6-sol` at `-c model_reasoning_effort='"high"'`
(`medium`/`low` only for small or mechanical work).

## Happy path

1. **Isolate.** Read-only work runs in the current checkout with `-s read-only`:

   ```bash
   slug="codex-$(date +%Y%m%d-%H%M%S)"
   run_dir="/tmp/codex-$slug"; mkdir -p "$run_dir"
   ```

   Edit work gets its own worktree instead, so the diff is easy to inspect or
   discard:

   ```bash
   slug="codex-$(date +%Y%m%d-%H%M%S)"
   worktree="../$(basename "$PWD")-$slug"
   git worktree add -b "agent/codex/$slug" "$worktree" HEAD
   run_dir="$worktree/.agent-runs/$slug"; mkdir -p "$run_dir"
   ```

2. **Write the brief** to `$run_dir/prompt.md`.
   Include context, exact task, constraints, verification commands, output
   contract — and a **hard completion criterion**: GPT-5.6 Sol is exploratory
   and keeps widening scope without an unambiguous definition of "done".

3. **Launch.** Always feed the prompt from the file with `- < prompt.md`; never
   pass it as a bare argument under a harness (see Gotchas: stdin wedge).

   Read-only reviewer / second opinion:

   ```bash
   codex exec -C "$PWD" \
     -m gpt-5.6-sol -c model_reasoning_effort='"high"' \
     -s read-only --json -o "$run_dir/final.md" \
     - < "$run_dir/prompt.md" > "$run_dir/events.jsonl"
   ```

   Edit worker — same command with `-C "$worktree"` and
   `--sandbox workspace-write` instead of `-s read-only`.

   Research briefs that need current information: add `-c tools.web_search=true`.

4. **Harvest.** Final answer in `$run_dir/final.md`; session id in the
   `thread.started` event's `thread_id` field in `$run_dir/events.jsonl` —
   keep it, it is the only safe handle for a follow-up turn (see Gotchas).
   For edit work also:
   diff via `git -C "$worktree" diff` — harvest from the **working tree**, not
   branch history, since the worker's commits may be missing (see Gotchas) —
   and run a fresh read-only reviewer over the diff before merging.

## Gotchas

- **A missing `codex` binary or stale auth surfaces mid-run** as an abort — or
  a hang indistinguishable from the stdin wedge. Preflight `codex --version`
  and auth (`codex login`, ChatGPT auth, or a scoped
  `CODEX_API_KEY`/`OPENAI_API_KEY`) before long runs.
- **Stdin wedge.** `codex exec` reads piped stdin whenever you pass `-`, no
  prompt, or a prompt *argument* — and under a harness stdin never closes, so it
  wedges at startup (0% CPU, no output). Use `- < prompt.md`, or add
  `< /dev/null` to any argument form. Never `codex exec "$(cat prompt.md)"` bare.
- **Workers cannot commit in a linked worktree.** The sandbox can't write the
  parent repo's `.git/worktrees/<name>`, so `git commit`/`git merge` fail even
  with `workspace-write`. The orchestrator runs all git commands; workers only
  edit and resolve content. Commit-shaped deliverable: brief the worker "commit;
  if commit fails, produce a `git bundle`" and fetch from the bundle.
- **`codex exec review --base <ref>` recurses on 0.144.1** — re-execs itself endlessly, emits
  no findings, leaves stray processes. Review with plain `codex exec
  -s read-only` and a "review the diff between <sha> and HEAD" prompt instead.
- **`codex exec resume` silently drops the original sandbox.** It accepts `-m`,
  `-c`, `--json`, `-o` but rejects `-C` and `-s` (exit 2), so the resumed turn
  takes `sandbox_mode` from `~/.codex/config.toml` — a run launched
  `-s read-only` resumes with whatever the config says, up to
  `danger-full-access`. Re-assert it through `-c`, which is accepted:
  `codex exec resume "$thread_id" -m gpt-5.6-sol -c sandbox_mode='"read-only"'
  --json -o resume.md "..." < /dev/null`. Re-pass `-m` too, or the resume runs
  on the config's model.
- **Resume by id, not `--last`.** `--last` picks the newest recorded session in
  the cwd, which is the wrong thread as soon as any other codex run has started
  since. Use the `thread_id` from the `thread.started` event; it stays stable
  across resumes of the same thread.
- **Resume cannot change the working directory** (`-C` rejected), so a thread is
  pinned to the tree it started in. Cross-tree follow-ups need a fresh run.
- **A crashing MCP server in `~/.codex/config.toml` aborts the whole run.** Pass
  `--ignore-user-config` (auth still resolves via `CODEX_HOME`) and re-specify
  `-m`/`-c` on the CLI.
- ChatGPT-plan usage limits abort runs mid-flight with a reset time. Fall back
  to another vendor until then.
- `-s read-only` is a hard filesystem boundary — commands that write caches or
  build artifacts fail under it.
- `-p` selects a config profile, not an agent persona; custom subagents are TOML
  files under `.codex/agents/` or `~/.codex/agents/`.
- `codex apply` applies the latest agent diff to the *current* tree — check
  `pwd` and branch first.
- Worktrees omit ignored files. Copy only explicit prerequisites (e.g.
  `.env.local`), never secret directories. If the worker needs uncommitted
  local changes, apply an explicit patch in the worktree — never checkpoint
  unrelated user WIP with `git add -A`.

## Not possible

- No approval prompts in exec mode: `-a/--ask-for-approval` is rejected.
- No `--search` flag on `codex exec` — use `-c tools.web_search=true`.
- No worktree creation or cleanup — manage them yourself.
- No resuming `--ephemeral` runs.
- The sandbox is not security isolation:
  `--dangerously-bypass-approvals-and-sandbox` only inside a bounded
  container/VM/CI runner — a worktree is not a security sandbox.

Evidence and full mechanics behind each gotcha: `reference/gotchas.md`.
