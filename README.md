# CLI subagent skills

Skills that let an agent drive another coding CLI programmatically for a second
opinion, a code review, or a delegated worker run. Each skill ships a
read-only reviewer and an edit-capable worker/profile.

The important trick is not just "how to launch the CLI"; it is how to launch it
without losing control of the main checkout. Prefer isolated branches/worktrees,
machine-readable output, and explicit run state.

| Skill | CLI | Model default | Read-only vs edit mechanism |
|-------|-----|---------------|-----------------------------|
| [`delegate-to-claude-code`](delegate-to-claude-code/SKILL.md) | `claude` | Opus 4.8 @ high; Sonnet 5 @ low for trivial tasks | `--permission-mode plan` vs `--permission-mode acceptEdits` / `auto`; bypass only in isolated sandboxes |
| [`delegate-to-codex`](delegate-to-codex/SKILL.md) | `codex exec` | GPT-5.5 @ high | `-s read-only` vs `--sandbox workspace-write -a never`; danger bypass only in isolated sandboxes |
| [`delegate-to-opencode`](delegate-to-opencode/SKILL.md) | `opencode run` | GLM-5.2 | primary/all agents with `edit: deny` vs `edit: allow` + `--auto` |

## Shared conventions

- **Worktree first for edits.** Launch edit workers in a new branch/worktree so
  long runs do not modify the main agent's checkout. Commit or patch in only the
  exact local state the worker needs; do not blindly `git add -A` unrelated work.
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
