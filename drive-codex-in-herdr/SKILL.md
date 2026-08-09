---
name: drive-codex-in-herdr
description: Drive an interactive Codex CLI TUI in a background herdr pane — multi-turn delegation where you keep prompting the same live session, answer its approval prompts, and watch it in a pane. Use for herdr-based codex delegation, `herdr agent start/prompt/wait/read`, conversational follow-ups on one codex thread, approval gates that need answering mid-run, and long-lived workers that outlive this session. For one-shot non-interactive runs, use delegate-to-codex instead.
compatibility: Requires the herdr and codex CLIs plus jq, this agent running inside a herdr-managed pane (HERDR_ENV=1), and the bundled scripts/codex-pane-up helper on PATH.
---

# Drive Codex in herdr

Run the **interactive** codex TUI in a background herdr pane and prompt it turn
after turn over one live thread. Use this over `delegate-to-codex` when the work
is conversational, needs approval answers mid-run, or should stay alive after
this session ends. One-shot review or edit work is cheaper with `codex exec`.
Model default: `-m gpt-5.6-sol -c model_reasoning_effort='"high"'`
(`gpt-5.6-luna` + `low` for smoke tests and mechanical work).

## Happy path

1. **Check you are inside herdr.** Everything below talks to the session's
   socket; from outside you would be driving someone else's panes.

   ```bash
   test "${HERDR_ENV:-}" = 1
   ```

2. **Bring up the pane.** `herdr agent start` alone is not enough — see Gotchas
   for the races it loses. Use the bundled helper, which splits a background
   pane, retries until the shell accepts an agent, starts codex, clears startup
   modals, and prints the pane id:

   ```bash
   pane=$(codex-pane-up reviewer "$PWD" \
     -m gpt-5.6-sol -c model_reasoning_effort='"high"' -s read-only)
   ```

   Edit worker — its own worktree, and a sandbox that can write to it:

   ```bash
   slug="codex-$(date +%Y%m%d-%H%M%S)"
   wt="../$(basename "$PWD")-$slug"
   git worktree add -b "agent/codex/$slug" "$wt" HEAD
   pane=$(codex-pane-up worker "$wt" \
     -m gpt-5.6-sol -c model_reasoning_effort='"high"' -s workspace-write)
   ```

3. **Prompt, one turn at a time.** `--wait` returns when the agent settles into
   `idle`, `done`, or `blocked`; the exit status does not tell you which.

   ```bash
   herdr agent prompt reviewer "Review the diff between HEAD~1 and HEAD. Actionable findings only." --wait --timeout 600000
   herdr agent get reviewer | jq -r '.result.agent.agent_status'
   ```

4. **Branch on the settled status.** `blocked` means codex is holding an
   approval or question dialog; read the screen, decide, and answer with keys —
   `enter` confirms the selected option, `down`/`up` move, `esc` cancels:

   ```bash
   herdr agent read reviewer --source detection      # the dialog itself
   herdr agent send-keys reviewer enter
   herdr agent wait reviewer --until idle --until done --timeout 600000
   ```

5. **Harvest, then keep going.** The same agent name stays valid for follow-up
   turns with model, sandbox, and cwd all intact — that is the whole point of
   this path over `codex exec resume`.

   ```bash
   herdr agent read reviewer --source recent-unwrapped --lines 200
   herdr agent prompt reviewer "Now check the test file too." --wait --timeout 600000
   ```

6. **Close the pane** when done, and only if you created it:
   `herdr pane close "$pane"`. Leave it open if the user wants to take it over.

## Gotchas

- **A freshly split pane is not a usable pane.** `pane split` returns before the
  shell is an "available shell", so an immediate `agent start` fails
  `agent_pane_busy`. Do not try to predict readiness — `pane process-info`
  showing only the shell pid still races and fails. Retry `agent start` on
  `agent_pane_busy` and treat any other error as fatal. The helper does this.
- **A failed bring-up leaks a pane.** `pane split` succeeds before whatever
  fails after it, and nothing reaps the pane. Close it on every error path or
  the user accumulates dead shells.
- **`idle` and `interactive_ready: true` do not mean "ready for a prompt".**
  Codex boots behind startup modals — update offers, hook-trust review — and
  herdr reports idle for all of them. A prompt sent then is swallowed by the
  dialog: the first turn returns `agent_prompt_stalled`, the second "succeeds"
  while only pressing dialog keys. Never prompt until
  `agent read --source detection` shows the composer footer (`<model> <effort>
  · <cwd>`). The helper does this.
- **`agent prompt --wait` returning 0 is not success.** It settles on `blocked`
  just as happily as `done`. Always read `agent_status` before reading output.
- **`-s read-only` is not a hard boundary in the TUI.** With `-a on-request`,
  approving a command runs it outside the sandbox (`Environment: local`) — a
  read-only worker wrote a file after one `enter`. Only `-a never` (the default
  from `approval_policy = "never"`) makes the sandbox absolute. Do not answer an
  approval you would not have granted on the CLI.
- **`agent read` returns the UI, not a transcript.** Box borders, MCP warnings,
  and hard-wrapped lines come with it, and it costs a scroll pass. It does
  recover long messages (a 120-line reply came back whole at `--lines 400`), but
  for any substantial deliverable have the worker write Markdown to a path and
  read the file instead.
- **Trusting herdr's own codex hook once removes a modal and improves
  detection.** `herdr integration install codex` writes a SessionStart hook to
  `~/.codex/hooks.json`; until trusted, every codex launch stops on "Hooks need
  review", and status stays screen-inferred. Trust is granted interactively
  ("Trust all and continue") and persists.
- **Names are aliases for a pane's current occupant**, not durable ids. A name
  clears when that codex exits. Re-resolve with `herdr agent list` rather than
  assuming a name still points anywhere.
- **A crashing MCP server in `~/.codex/config.toml` degrades the TUI run** the
  same way it does `codex exec`, but the TUI has no `--ignore-user-config`
  escape — that flag exists only on `exec`. Fix the config or accept the noise.

## Not possible

- No `--ignore-user-config` on the interactive TUI; only `codex exec` has it.
- No structured event stream — there is no TUI equivalent of `exec --json`;
  status classification is all you get.
- No headless operation: this needs a live herdr session and pane.
- herdr is a multiplexer, not a sandbox. Pane isolation is cosmetic; the
  sandbox flag and the worktree are the only real boundaries.

Evidence for each gotcha, including the live transcripts: `reference/gotchas.md`.
