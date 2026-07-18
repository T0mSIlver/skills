---
name: delegate-to-opencode
description: "Call the opencode CLI (`opencode run`) non-interactively to get a second opinion, run a code review, or delegate read-only or edit-capable work to an independent opencode run. Use for GLM-5.2/opencode harness delegation, primary/all agent configs with edit permissions, worktree-isolated edit workers, JSON event capture, session resume/fork flows, and gotchas around `mode: subagent`, `--auto`, prompt files, and `--dir`."
---

# Delegate to opencode (CLI)

Run `opencode run` non-interactively for a second opinion, review, or a
delegated edit worker. Model default: `-m zai-coding-plan/glm-5.2` (verify the
slug with `opencode models | grep glm`; don't hard-code `temperature`).

## Happy path

1. **Isolate and install agents.** Copy the bundled agents (they are
   `mode: all`, required for direct `--agent` launches) into
   `.opencode/agents/` of the checkout the run will use — opencode resolves
   `--agent` against `--dir`, so the agent must live there. Read-only review
   runs in the current checkout:

   ```bash
   slug="opencode-$(date +%Y%m%d-%H%M%S)"
   skill_dir="<directory containing this SKILL.md>"
   run_dir="/tmp/opencode-$slug"
   mkdir -p "$run_dir" .opencode/agents
   cp "$skill_dir/assets/reviewer.md" .opencode/agents/
   ```

   Edit work gets its own worktree instead (opencode never creates one):

   ```bash
   worktree="../$(basename "$PWD")-$slug"
   git worktree add -b "agent/opencode/$slug" "$worktree" HEAD
   run_dir="$worktree/.agent-runs/$slug"
   mkdir -p "$run_dir" "$worktree/.opencode/agents"
   cp "$skill_dir/assets/editor.md" "$worktree/.opencode/agents/"
   ```

2. **Write the brief** to `$run_dir/prompt.md`:
   context, exact task, constraints, acceptance criteria, verification commands,
   required final output. It reaches opencode inline as the positional message —
   `"$(cat prompt.md)"`. `--file` cannot carry the prompt (see Gotchas).

3. **Launch.** Three wrappers are mandatory: `< /dev/null` (stdin wedge),
   `timeout` (no stream timeout), and the output-cap env var (32k clamp):

   ```bash
   OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=131072 \
   timeout --signal=TERM 2700 opencode run \
     --dir "$worktree" \
     --agent editor \
     -m zai-coding-plan/glm-5.2 \
     --format json \
     --title "$slug" \
     --auto \
     "$(cat "$run_dir/prompt.md")" \
     < /dev/null \
     > "$run_dir/events.jsonl"
   ```

   Reviewer: same command with `--agent reviewer` and `--dir "$PWD"`.
   Stagger concurrent runs past two per machine (see Gotchas).

4. **Harvest.** Parse the final text event and `sessionID` from `events.jsonl`.
   Exit 0 does not mean an answer — always check the finish reason:

   ```bash
   jq -r 'select(.type=="step_finish") | .part.reason' "$run_dir/events.jsonl" \
     | grep -qx length && echo "TRUNCATED - raise OUTPUT_TOKEN_MAX or shorten the brief"
   ```

   `stop` is healthy. Hung-run check: `events.jsonl` still 0 bytes after ~5 min,
   or mtime stale >10 min → kill and relaunch. Resume with
   `opencode run --continue "..." < /dev/null` or `--session <id>`; add `--fork`
   to branch without mutating the original.

## Gotchas

- **Missing `< /dev/null` wedges the run at `init`** — under a harness, stdin
  is a pipe that never closes and opencode parks on it before creating a
  session. Symptom: 0-byte `events.jsonl` from the start, log ends at `init`
  with no `created id=ses_...`. Check this before anything else.
- **Silent provider stalls hang forever** (no stream timeout; only explicit
  provider errors retry). The `timeout` wrapper is what turns a zombie into a
  clean failure.
- **A third concurrent instance has hung at startup** (zero log entries,
  blocked on the shared SQLite/WAL db under `~/.local/share/opencode/`) —
  observed once on 1.17.13, so treat "stagger past two" as a conservative
  heuristic, not a documented limit.
- **Output is clamped to 32k tokens including reasoning** — a thinking-heavy
  brief can burn it all and emit nothing, with exit 0 and `reason: "length"`.
  Set `OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX` to the model's real
  `limit.output` (models.dev/api.json); it can only raise toward the ceiling.
  On models without `limit.input` (glm-5.2 included) it shrinks usable context
  one-for-one — match the value to the model, don't set one number globally.
- **`--file` never carries the prompt** — it only attaches files, a positional
  message is still required, and the flag greedily swallows positionals that
  follow it (`--file prompt.md "do X"` dies with `File not found: do X`). Put
  the message BEFORE the flag, or inline with `"$(cat prompt.md)"`.
- **`mode: subagent` agents can't be launched with `--agent`** — opencode
  silently falls back to the default agent, dropping your permission setup. Use
  `mode: all` or `primary`; verify with `opencode agent list`.
- `--auto` auto-approves but explicit `deny` rules still hold — `edit: deny`
  stays safe for reviewers.
- **A dead mid-run worker loses the conversation, not the code** — its edits
  are on disk in the worktree. Recover with a continue-brief to a fresh run:
  read the original prompt + `git diff`, judge the partial work critically,
  finish, verify.
- The shared log is `~/.local/share/opencode/log/opencode.log` (UTC); grep
  `run=`/`agent=` to tell "never initialized" from "stalled mid-stream".
- Worktrees omit ignored files; copy only explicit prerequisites. If the worker
  needs uncommitted local changes, apply an explicit patch in the worktree —
  never checkpoint unrelated user WIP with `git add -A`.

## Not possible

- No native worktree creation — manage git worktrees yourself.
- No stream/idle timeout — external `timeout` is the only guard.
- No `opencode.json` key for the output cap — env var only.
- No `--format json` on `opencode agent list` (text output).
- No prompt via `--file` alone — a positional message is always required.
- `--dir` with `--attach` is a path on the remote server, not local.

## Inline config alternative

Instead of the markdown assets, declare the agents in `opencode.json`
(`"$schema": "https://opencode.ai/config.json"`): mirror each asset's
frontmatter — `description`, `mode`, `model`, `permission` — as
`agent.reviewer` / `agent.editor` objects under the top-level `agent` key.

Evidence, exact failure modes, and the output-cap analysis: `reference/gotchas.md`.
