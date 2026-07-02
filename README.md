# CLI subagent skills

Skills that let an agent drive another coding CLI programmatically for a second
opinion, a code review, or a delegated worker run. Each skill ships a
read-only reviewer and an edit-capable worker/profile.

The important trick is not just "how to launch the CLI"; it is how to launch it
without losing control of the main checkout. Prefer isolated branches/worktrees,
machine-readable output, and explicit run state.

| Skill | CLI | Purpose |
|-------|-----|---------|
| [`delegate-to-claude-code`](delegate-to-claude-code/SKILL.md) | `claude` | Delegate reviewer/editor runs; `--permission-mode plan` vs `acceptEdits` / `auto` |
| [`claude-remote-control-server`](claude-remote-control-server/SKILL.md) | `claude remote-control` | Run persistent per-repo Remote Control servers under systemd |
| [`delegate-to-codex`](delegate-to-codex/SKILL.md) | `codex exec` | Delegate reviewer/editor runs; `-s read-only` vs `workspace-write` |
| [`delegate-to-opencode`](delegate-to-opencode/SKILL.md) | `opencode run` | Delegate reviewer/editor runs; primary/all agents with `edit: deny` vs `edit: allow` |

## Shared conventions

- **Worktree first for edits.** Launch edit workers in a new branch/worktree so
  long runs do not modify the main agent's checkout. Commit or patch in only the
  exact local state the worker needs; do not blindly `git add -A` unrelated work.
- **Remote-visible Claude sessions.** For Claude Code delegation, prefer
  `claude-rc-spawn`: it starts interactive Claude in detached tmux with Remote
  Control enabled, injects the prompt, and leaves a session the user can inspect
  from claude.ai/code.
- **Prompt as a file.** Write the brief to a markdown file with context, task,
  constraints, acceptance criteria, and required output shape. Feed or attach
  that file instead of hand-writing a large inline string.
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
- Long prompt files are great, but command-line argument length still exists.
  Prefer stdin where supported; for opencode, use `--file` for very large briefs.

Each skill directory contains a `SKILL.md` with concrete commands and an
`assets/` folder with drop-in agent/profile configs.

## Keep local native skill folders current

This repo includes a small sync setup that keeps the same skill versions
available to Claude Code, Codex, and opencode:

| Location | Serves |
|----------|--------|
| `~/.claude/skills/` | Claude Code (native) |
| `~/.codex/skills/` | Codex (native) |
| `~/.config/opencode/skills/` | opencode (native) |

Install the user-level timer:

```bash
scripts/install-sync-timer.sh
```

The timer runs every 2 minutes. Each run fetches `origin/main`, exports that
fetched tree into a temporary directory, and then syncs every top-level
directory containing a `SKILL.md` into the three native locations. If GitHub
fetching fails because credentials or the network are unavailable, the sync
still updates the native folders from the current local checkout. It updates
only skills managed by this repo and leaves unrelated local skills alone. It
also installs repo-managed helper commands, such as `claude-rc-spawn` and
`install-claude-rc-server-service.sh`, into `~/.local/bin`.

For private GitHub repos, the timer needs noninteractive git credentials. The
installer imports currently available `GITHUB_TOKEN`, `GH_TOKEN`, and
`SSH_AUTH_SOCK` values into the user systemd manager without writing them to the
unit file.

Useful commands:

```bash
scripts/sync-skills.sh
scripts/install-claude-rc-server-service.sh
systemctl --user status skills-sync.timer
systemctl --user status claude-rc-skills.service
journalctl --user -u skills-sync.service -n 80 --no-pager
journalctl --user -u claude-rc-skills.service -n 80 --no-pager
```
