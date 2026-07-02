---
name: delegate-to-opencode
description: Call the opencode CLI (`opencode run`) non-interactively to get a second opinion, a code review, or to run it as a subagent that reads/investigates or edits code. Use when you want an independent opencode (GLM-5.2) run — e.g. "get a second opinion from opencode", "have opencode review this", "delegate this to an opencode subagent", or spawn a read-only reviewer vs. an edit-capable worker.
---

# Delegate to opencode (CLI)

Run the `opencode` CLI programmatically via `opencode run` (non-interactive) to get a
second opinion, a review, or to delegate a task to a subagent. Two agent configs are
provided: a **read-only reviewer** and an **edit-capable worker**.

## Prerequisites

- `opencode` is on PATH (`opencode --version`). Configure the provider/credentials once
  with `opencode auth login` (aka `opencode providers`). In a non-interactive/sandbox
  context, auth must already be set up.
- Run from inside the target repo, or pass `--dir <path>`.

## Model default

Always use **GLM-5.2**. In opencode the model is `provider/model-id`:

```
-m zai-coding-plan/glm-5.2
```

(Verify the exact provider slug with `opencode models | grep glm-5.2`.)

## The two agent configs

opencode agents carry their own **permissions**, which make an agent read-only vs.
edit-capable. Set the `edit` (and `bash`) permission to `deny` for read-only, or `allow`
for an edit worker. Drop-in agent files are in `assets/`:

- `assets/reviewer.md` → read-only reviewer (`edit: deny`, `bash: deny`)
- `assets/editor.md` → edit worker (`edit: allow`, `bash: allow`)

Install them (project-local shown; use `~/.config/opencode/agent/` for global):

```bash
mkdir -p .opencode/agent && cp assets/reviewer.md assets/editor.md .opencode/agent/
```

### Read-only reviewer / second opinion

```bash
opencode run --agent reviewer -m zai-coding-plan/glm-5.2 --format json \
  "Review the changes on this branch for correctness bugs. Report findings only."
```

Because the reviewer agent denies `edit`/`bash`, it cannot modify files and never needs
an approval prompt.

### Edit worker (has the harness edit tool)

```bash
opencode run --agent editor -m zai-coding-plan/glm-5.2 --format json \
  "Fix the failing test in test/auth.test.ts and make it pass."
```

The editor agent sets `edit: allow` / `bash: allow`, so changes apply without prompting.
If you invoke an edit-capable agent whose permissions still `ask`, add `--auto` to
auto-approve everything not explicitly denied (use only in a trusted sandbox).

## Capturing the result

- `--format json` → raw JSON events on stdout; parse the final assistant message.
- `--format default` (default) → formatted text.
- Prompt as positional args or via `--prompt "..."`.
- Attach files with `-f/--file`; set a session title with `--title`.

## Defining agents inline (config alternative)

Instead of markdown files you can declare both agents in `opencode.json` at the repo root:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "reviewer": {
      "description": "Read-only second-opinion reviewer",
      "mode": "subagent",
      "model": "zai-coding-plan/glm-5.2",
      "permission": { "edit": "deny", "bash": "deny", "webfetch": "allow" }
    },
    "editor": {
      "description": "Edit-capable worker subagent",
      "mode": "subagent",
      "model": "zai-coding-plan/glm-5.2",
      "permission": { "edit": "allow", "bash": "allow" }
    }
  }
}
```

## Notes

- `opencode run` is one-shot. Continue the last session with `-c/--continue`, or a specific
  one with `-s/--session <id>` (add `--fork` to branch off it).
- Permission keys include `read, edit, bash, glob, grep, webfetch, websearch, task`; each is
  `allow`, `ask`, or `deny`. Agent-level permissions override global config.
- `--variant <high|max|minimal>` sets provider-specific reasoning effort when the model
  supports it.
