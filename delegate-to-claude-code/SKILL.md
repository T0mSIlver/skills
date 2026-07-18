---
name: delegate-to-claude-code
description: Call the Claude Code CLI (`claude`) as a delegated reviewer, second opinion, or edit worker. Use for Claude Code subagent-style delegation with `claude-rc-spawn`, `claude -p`, `--bg`, `--worktree`, `--tmux`, plan/read-only reviewers, acceptEdits/auto edit workers, JSON/stream-json capture, resume flows, and gotchas around permission modes, worktree cleanup, agent personas, and `--dangerously-skip-permissions`. For persistent `claude remote-control` repo servers, use the claude-remote-control-server skill instead.
---

# Delegate to Claude Code (CLI)

Run `claude` for a second opinion, review, or a delegated edit worker. Default
path: `claude-rc-spawn` — interactive Claude in detached tmux with Remote
Control, so the user can watch and steer from claude.ai/code. Use plain
`claude -p` when machine-readable capture matters more than visibility.
Model default: `--model opus --effort high` (`sonnet --effort low` for trivia).

## Happy path

1. **Write the brief** to `.agent-runs/$slug/prompt.md` (`slug="claude-$(date
   +%Y%m%d-%H%M%S)"`): context, exact task, constraints, acceptance criteria,
   verification commands, output shape. Demand evidence (commands run, exit
   status, changed files, risks) and state explicitly: **verify synchronously —
   never end the turn waiting on a background monitor or watcher.** Workers
   otherwise park themselves "waiting for the monitor" and yield-loop.

2. **Launch.** Reviewer (read-only) via Remote Control tmux:

   ```bash
   claude-rc-spawn \
     --cwd "$PWD" \
     --prompt-file ".agent-runs/$slug/prompt.md" \
     --name "$slug-review" --tmux-session "$slug-review" \
     --permission-mode plan \
     --model opus --effort high
   ```

   Edit worker: same command, replacing `--permission-mode plan` with
   `--permission-mode acceptEdits` and adding `--worktree "$slug"` (Claude
   creates the worktree and branch).

   Noninteractive fallback (JSON capture, no Remote Control):

   ```bash
   cat ".agent-runs/$slug/prompt.md" | claude -p \
     --model opus --effort high \
     --permission-mode plan \
     --output-format json \
     --name "$slug-review" --add-dir .
   ```

   For an edit worker replace `--permission-mode plan` with
   `--permission-mode acceptEdits`, replace `--output-format json` with
   `--output-format stream-json --verbose`, and add `--worktree "$slug"
   --max-budget-usd 10`. For a fire-and-return background worker use
   `claude --bg --worktree "$slug" --permission-mode acceptEdits
   --name "$slug-edit" "$(cat ".agent-runs/$slug/prompt.md")"` and manage it
   with `claude agents --json`.

3. **Harvest.** `--output-format json`: final text in `.result`, session id in
   `.session_id`; `stream-json --verbose` for live logs. `claude-rc-spawn`
   saves the prompt and `tmux.log` under `.agent-runs/<tmux-session>/`. Watch
   with `tmux attach -t "$slug-review"` or from claude.ai/code by name. Resume
   with `claude --continue` / `--resume <session-id>`; add `--fork-session` to
   branch. For large work, split maker and checker: run a fresh reviewer over
   the diff before accepting.

## Gotchas

- **Remote Control needs a full claude.ai login.** `CLAUDE_CODE_OAUTH_TOKEN`,
  `ANTHROPIC_API_KEY`, or a non-default `ANTHROPIC_BASE_URL` in the
  environment can break it before the session starts; `claude-rc-spawn` strips
  them by default. Remote Control dies with the local process — keep the tmux
  session alive until the run completes.
- **`--worktree` starts from `origin/HEAD`, not your branch.** Set
  `worktree.baseRef` to `head` when the worker must see local in-progress
  state. Worktrees land under `.claude/worktrees/<name>` (gitignore that dir);
  `-p --worktree` runs get no exit prompt, so clean up finished worktrees
  yourself.
- **A worker that ends its turn "waiting for a monitor" is stuck.** Nudge it
  once (resume the session or paste into its tmux session); if it parks again,
  take over — its edits are already on disk in the worktree.
- `--agent` selects a persona only; hard permissions come from
  `--permission-mode` (`plan`, `acceptEdits`, `auto`) — pair them every time.
- `--max-budget-usd` caps print-mode (`claude -p`) runs only.
- Add `--tmux` with `--worktree` when you want Claude Code's built-in tmux
  handling instead of `claude-rc-spawn`.
- `claude -p` skips the workspace-trust dialog — run it only in directories you
  trust.
- `--add-dir` grants file access; it does not make that directory the working
  checkout or copy its config.
- Name every run (`--name`) so concurrent agents are distinguishable in
  `claude agents` and claude.ai/code.

## Not possible

- Remote Control with API-key / `claude setup-token` /
  `CLAUDE_CODE_OAUTH_TOKEN` auth — full claude.ai login only.
- Budget caps on `--bg` background agents (`--max-budget-usd` is print-mode
  only).
- `--dangerously-skip-permissions` outside a bounded, preferably
  network-isolated container/VM — it can write protected config areas; never
  the default edit-worker mode.
- Persistent servers for future mobile/web dispatch — that is
  `claude remote-control` server mode; use the `claude-remote-control-server`
  skill.
