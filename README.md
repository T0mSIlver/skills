# CLI subagent skills

Skills that let an agent drive another coding CLI **programmatically** — for a second
opinion, a code review, or as a delegated subagent. Each skill ships two ready-to-use
agent configs: a **read-only reviewer** and an **edit-capable worker** (the latter has
access to that harness's edit tool).

| Skill | CLI | Model default | Read-only ↔ edit mechanism |
|-------|-----|---------------|----------------------------|
| [`delegate-to-claude-code`](delegate-to-claude-code/SKILL.md) | `claude` | Opus 4.8 @ high (Sonnet 5 @ low for trivial tasks) | `--permission-mode plan` ↔ `acceptEdits` |
| [`delegate-to-codex`](delegate-to-codex/SKILL.md) | `codex exec` | GPT-5.5 @ high | `-s read-only` ↔ `-s workspace-write` |
| [`delegate-to-opencode`](delegate-to-opencode/SKILL.md) | `opencode run` | GLM-5.2 | agent `edit: deny` ↔ `edit: allow` |

Each skill directory contains a `SKILL.md` with the concrete commands and an `assets/`
folder with the two drop-in agent/profile configs.
