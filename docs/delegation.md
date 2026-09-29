# Delegating to another coding CLI

These rules apply to any run handed to another CLI: `delegate-to-claude-code`,
`cross-review`, and the read-only Codex tasks in `quota-queue`. Codex and GLM
only review and research; Claude Code implements.

## Conventions

- **Edits happen in a worktree.** Start edit workers on a new branch in their
  own worktree, so a long run can't modify the orchestrator's checkout. Give
  the worker exactly the local state it needs. Never `git add -A` unrelated
  work to get it there.
- **The brief is a file.** Write context, task, constraints, acceptance
  criteria and the required output format to a markdown file, then pass the
  file's contents as the prompt. Large prompts typed inline break easily.
- **Save the run state.** Keep the harness output, session id, branch,
  worktree and prompt path. You need them to poll, resume, clean up and review
  a long run.
- **A reviewer checks the worker.** Don't trust the edit worker's final
  message. Before merging, cherry-picking or opening a PR, run a fresh
  read-only review of the diff, using a different model when you can.
- **Claude sessions go through `claude-rc-spawn`.** It starts interactive
  Claude in a detached tmux session with Remote Control on and sends the
  prompt. You can then open the session from claude.ai/code.

## Gotchas

- A branch can be checked out in only one worktree at a time.
- A fresh worktree doesn't contain ignored files such as `.env`. Copy only
  the files the run needs, ideally from a `.worktreeinclude`-style allowlist.
- A worktree prevents file collisions. It doesn't isolate secrets, the
  network or the machine. Bypass flags remove the harness's permission checks
  entirely, so use them only on a machine that is itself the sandbox.
- **Stdin hangs non-interactive runs.** Under a harness, the inherited stdin
  is a pipe that never closes. `codex exec` reads stdin even when you pass the
  prompt as an argument, so it waits forever at 0% CPU and never contacts the
  model. Always give stdin a source that ends: `< /dev/null` when the prompt
  is an argument, or `- < prompt.md` when stdin carries the prompt.
- opencode's `--file` attaches a file but never carries the prompt. It still
  needs a non-empty positional message, and `--file` must come *after* that
  message. Otherwise yargs treats the message as another file.
