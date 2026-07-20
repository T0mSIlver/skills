# CLI subagent skills

[Agent Skills](https://agentskills.io) that let a coding agent drive another
coding CLI programmatically — for a second opinion, a code review, or a
delegated worker run. Each `delegate-to-*` skill ships a read-only reviewer and
an edit-capable worker/profile.

The important trick is not just "how to launch the CLI"; it is how to launch it
without losing control of the main checkout. Prefer isolated branches/worktrees,
machine-readable output, and explicit run state.

| Skill | CLI | Purpose |
|-------|-----|---------|
| [`delegate-to-claude-code`](delegate-to-claude-code/SKILL.md) | `claude` | Delegate reviewer/editor runs; `--permission-mode plan` vs `acceptEdits` / `auto` |
| [`claude-remote-control-server`](claude-remote-control-server/SKILL.md) | `claude remote-control` | Run persistent per-repo Remote Control servers under systemd |
| [`delegate-to-codex`](delegate-to-codex/SKILL.md) | `codex exec` | Delegate reviewer/editor runs; `-s read-only` vs `workspace-write` |
| [`delegate-to-opencode`](delegate-to-opencode/SKILL.md) | `opencode run` | Delegate reviewer/editor runs; primary/all agents with `edit: deny` vs `edit: allow` |
| [`fastcontext`](fastcontext/SKILL.md) | `fastcontext` | Delegate read-only repository exploration; returns `file:line` citations without spending your context |

## Install

Each skill is a plain [Agent Skills](https://agentskills.io/specification)
folder, so any SKILL.md-aware tool can consume it. Pick a rail:

**`skills` CLI** (installs into Claude Code, Codex, opencode, Cursor, and
[many others](https://github.com/vercel-labs/skills)):

```bash
npx skills add T0mSIlver/skills                               # pick interactively
npx skills add T0mSIlver/skills -a claude-code -a codex -g -y # everything, globally
```

**Claude Code plugin marketplace:**

```text
/plugin marketplace add T0mSIlver/skills
/plugin install cli-delegation@t0msilver-skills
/plugin install claude-rc-server@t0msilver-skills
```

**Manual:** copy any top-level skill directory into your agent's skills folder
(`~/.claude/skills/`, `~/.codex/skills/`, `~/.config/opencode/skills/`, …).

Some skills need more than the folder copy — each declares its requirements in
`compatibility:` frontmatter:

- `fastcontext` requires the separate
  [**fastcontext** CLI](https://github.com/T0mSIlver/fastcontext#installation)
  on `PATH`; the skill checks for it at load and points you there if missing.
- `claude-remote-control-server` sets up a user systemd service via its bundled
  `scripts/install-claude-rc-server-service.sh` (nothing runs at install time —
  the skill walks the agent through it).
- `delegate-to-claude-code` prefers its `scripts/claude-rc-spawn` helper (needs
  `tmux`) on `PATH` for remote-visible sessions; plain `claude -p` delegation
  works without it.

## Shared conventions

- **Worktree first for edits.** Launch edit workers in a new branch/worktree so
  long runs do not modify the main agent's checkout. Commit or patch in only the
  exact local state the worker needs; do not blindly `git add -A` unrelated work.
- **Remote-visible Claude sessions.** For Claude Code delegation, prefer
  `claude-rc-spawn`: it starts interactive Claude in detached tmux with Remote
  Control enabled, injects the prompt, and leaves a session the user can inspect
  from claude.ai/code.
- **Prompt as a file.** Write the brief to a markdown file with context, task,
  constraints, acceptance criteria, and required output shape. Pass its contents
  as the prompt argument, or attach it, instead of hand-writing a large inline
  string.
- **Capture run state.** Save the harness output, session id, branch, worktree,
  and prompt path. Long runs need a handle for polling, resume, cleanup, and
  review.
- **Reviewer after worker.** Treat the edit worker's final message as a claim.
  Run a fresh read-only review against the diff before merging, cherry-picking,
  or opening a PR.

## Common gotchas

- A git worktree shares repository metadata, but each branch can be checked out
  in only one worktree at a time.
- Ignored local files such as `.env` do not magically appear in a fresh
  worktree. Copy only the files the run needs, preferably via a documented
  `.worktreeinclude`-style allowlist.
- Full-bypass flags remove the harness safety boundary. A worktree prevents file
  collisions, but it is not a secret, network, or machine sandbox.
- Stdin wedges non-interactive runs. Under a harness the inherited stdin is an
  open pipe that never closes, and `codex exec` reads stdin whenever you pass a
  prompt argument alongside it — so it blocks until EOF at 0% CPU, before it ever
  contacts the model. Always give stdin a source that reaches EOF: `< /dev/null`
  when the prompt is an argument, or `- < prompt.md` when the brief itself is the
  stdin.
- Pass the brief as an argument, not on stdin: inline the prompt file with
  `"$(cat prompt.md)"`. If a brief is too large to inline comfortably, opencode
  can attach it — but `--file` never carries the prompt. It still requires a
  non-empty positional message, and it must come *after* that message, or yargs
  swallows the message into the file list.

## Repo layout

Each skill directory contains a `SKILL.md` with concrete commands. Where
present, drop-in agent and profile configs live in the skill's `assets/`
folder (`agents/` for `claude-remote-control-server`), deep-dive evidence in
`reference/`, and skill-specific executable helpers in its `scripts/`
folder. The root `scripts/` directory is reserved for repo
maintenance scripts, and `.claude-plugin/marketplace.json` makes the repo
installable as a Claude Code plugin marketplace.

## Self-updating deployment (optional)

The author's own deployment loop — a systemd timer that syncs these skills from
`origin/main` into the Claude Code/Codex/opencode native folders, holds local
edits instead of overwriting them, and lets an agent upstream a fix from an
installed copy as a PR with one `skills-pr` command — is documented in
[docs/sync-system.md](docs/sync-system.md). You do not need it to use the
skills; the install rails above are the supported path.
