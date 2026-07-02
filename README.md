# CLI subagent skills

Skills that let an agent drive another coding CLI **programmatically** — for a second
opinion, a code review, or as a delegated subagent. Each skill ships two ready-to-use
agent configs: a **read-only reviewer** and an **edit-capable worker** (the latter has
access to that harness's edit tool).

They assume an **externally sandboxed environment**, so the edit worker runs fully
autonomously (no permission prompts).

| Skill | CLI | Model default | Read-only ↔ edit mechanism |
|-------|-----|---------------|----------------------------|
| [`delegate-to-claude-code`](delegate-to-claude-code/SKILL.md) | `claude` | Opus 4.8 @ high (Sonnet 5 @ low for trivial tasks) | `--permission-mode plan` ↔ `--dangerously-skip-permissions` |
| [`delegate-to-codex`](delegate-to-codex/SKILL.md) | `codex exec` | GPT-5.5 @ high | `-s read-only` ↔ `--dangerously-bypass-approvals-and-sandbox` |
| [`delegate-to-opencode`](delegate-to-opencode/SKILL.md) | `opencode run` | GLM-5.2 | agent `edit: deny` ↔ `edit: allow` + `--auto` |

## Shared conventions

- **Commit first.** Before delegating an edit task, `git commit` the working tree so the
  subagent's changes are isolated, reviewable (`git diff`), and never lost.
- **Prompt as a file.** Write a long, detailed prompt to a markdown file and feed it to
  the CLI (via stdin, or `"$(cat file)"` for opencode) instead of an inline string — no
  shell escaping, and room for a much richer brief (context, task, constraints, acceptance
  criteria).

Each skill directory contains a `SKILL.md` with the concrete commands and an `assets/`
folder with the two drop-in agent/profile configs.
