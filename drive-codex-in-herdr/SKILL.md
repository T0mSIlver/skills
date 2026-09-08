---
name: drive-codex-in-herdr
description: Sandbox and user-config rules for running the interactive Codex CLI TUI in a herdr pane — what actually bounds a codex worker, and which `codex exec` escape hatches the TUI does not have. Use alongside the `herdr` skill whenever starting a codex agent with `herdr agent start --kind codex`. For one-shot non-interactive runs, use delegate-to-codex instead.
compatibility: Requires the herdr and codex CLIs and this agent running inside a herdr-managed pane (HERDR_ENV=1).
---

# Drive Codex in herdr

The [`herdr`](../herdr/SKILL.md) skill is the authority on the CLI itself —
panes, `agent start/prompt/wait/read`, and the coordination rules. It covers the
mechanics; this covers the two things it cannot know, both about **codex**.

Model default: `-m gpt-5.6-sol -c model_reasoning_effort='"high"'`
(`gpt-5.6-luna` + `low` for smoke tests and mechanical work).

## The sandbox is the only real boundary

herdr is a multiplexer, not a sandbox — a pane is cosmetic isolation. What
bounds a codex worker is the flags it was started with, passed after `--`:

```bash
herdr agent start reviewer --kind codex --pane <pane-id> -- -s read-only -a never
```

- **`-a never` is what makes `-s read-only` real.** Under `-a on-request`,
  approving a command runs it *outside* the sandbox — the dialog says
  `Environment: local`, and a read-only worker wrote a file after one `enter`.
  Only `-a never` makes the sandbox absolute. Do not answer an approval you
  would not have granted on the CLI.
- **Pass `-s` explicitly, always.** `~/.codex/config.toml` sets
  `sandbox_mode = "danger-full-access"`, so a codex started without `-s`
  inherits full access to the machine.
- **For an edit worker the worktree is the other half of the boundary.**
  Resolve the path before handing it over; `--cwd` should not be relative:

  ```bash
  slug="codex-$(date +%Y%m%d-%H%M%S)"
  git worktree add -b "agent/codex/$slug" "../$(basename "$PWD")-$slug" HEAD
  wt=$(cd "../$(basename "$PWD")-$slug" && pwd -P)
  herdr pane split --current --direction right --cwd "$wt" --no-focus
  herdr agent start worker --kind codex --pane <pane-id> -- -s workspace-write -a never
  ```

Unlike `codex exec resume` — which rejects `-s` and falls back to the config's
`sandbox_mode` — a live TUI pane keeps the policy it launched with across every
follow-up turn.

## The TUI has no user-config escape

`--ignore-user-config` exists only on `codex exec`. A crashing MCP server in
`~/.codex/config.toml` degrades an interactive pane with no way to opt out: fix
the config or accept the noise.

Evidence for both sections, with live transcripts: `reference/gotchas.md`.
