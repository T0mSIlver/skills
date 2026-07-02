---
name: delegate-to-opencode
description: Call the opencode CLI (`opencode run`) non-interactively to get a second opinion, a code review, or to run it as a subagent that reads/investigates or edits code. Use when you want an independent opencode (GLM-5.2) run — e.g. "get a second opinion from opencode", "have opencode review this", "delegate this to an opencode subagent", or spawn a read-only reviewer vs. an edit-capable worker.
---

# Delegate to opencode (CLI)

Run the `opencode` CLI programmatically via `opencode run` (non-interactive) to get a
second opinion, a review, or to delegate a task to a subagent. Two agent configs are
provided: a **read-only reviewer** and an **edit-capable worker**.

These skills assume you are running inside a **sandboxed environment**, so the edit worker
is granted full autonomy via `--auto` (auto-approve everything not explicitly denied) —
permission gating is not needed.

## Prerequisites

- `opencode` is on PATH (`opencode --version`) and the provider is configured
  (`opencode auth login`).
- Run from inside the target repo, or pass `--dir <path>`.

## Step 1 — Commit first (before an edit task)

Before delegating anything that edits files, **commit your current work** so nothing can
be lost and the subagent's changes are isolated and reviewable:

```bash
git add -A && git commit -m "checkpoint before delegating to opencode"
```

Then inspect exactly what the subagent did with `git diff` and revert cleanly if needed.
(Harmless to do before a read-only review too.)

## Step 2 — Write the prompt to a markdown file

**Always put the prompt in a markdown file and pass it via `"$(cat file)"` — do not fight
the shell with a hand-written inline string.** This lets you write a long, detailed,
well-structured prompt (headings, code blocks, file lists, acceptance criteria) with zero
quoting/escaping issues. Use your Write tool to create it:

```
/tmp/oc-prompt.md
```

**Invest in the prompt.** A detailed brief gets a dramatically better result than a
one-liner. Include:

- **Context**: what the project is, the relevant files/paths, and how they fit together.
- **Task**: precisely what you want done or reviewed, and what is out of scope.
- **Constraints**: conventions to follow, things not to touch, libraries to prefer.
- **Acceptance criteria**: how the subagent should know it succeeded (tests pass, specific
  behavior), and what to return (a findings list, a diff summary, etc.).

## Step 3 — Model default

Always use **GLM-5.2**. In opencode the model is `provider/model-id`:

```
-m zai-coding-plan/glm-5.2
```

(Verify the exact provider slug with `opencode models | grep glm-5.2`.)

## Step 4 — Run one of the two agent configs

The read-only vs. edit distinction comes from each agent's `edit` permission. Drop-in
agent files are in `assets/`:

- `assets/reviewer.md` → read-only reviewer (`edit: deny`)
- `assets/editor.md` → edit worker (`edit: allow`)

Install them (project-local shown; use `~/.config/opencode/agent/` for global):

```bash
mkdir -p .opencode/agent && cp assets/reviewer.md assets/editor.md .opencode/agent/
```

### Read-only reviewer / second opinion

The reviewer agent denies `edit`, so it cannot modify files no matter what:

```bash
opencode run --agent reviewer -m zai-coding-plan/glm-5.2 --format json --auto \
  "$(cat /tmp/oc-prompt.md)"
```

### Edit worker (has the harness edit tool)

The editor agent allows `edit`; `--auto` auto-approves everything else so the run is fully
non-interactive in the sandbox:

```bash
opencode run --agent editor -m zai-coding-plan/glm-5.2 --format json --auto \
  "$(cat /tmp/oc-prompt.md)"
```

## Capturing the result

- `--format json` → raw JSON events on stdout; parse the final assistant message.
- `--format default` (default) → formatted text.
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
      "permission": { "edit": "deny", "bash": "allow", "webfetch": "allow" }
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
  `allow`, `ask`, or `deny`. Agent-level permissions override global config, so a denied
  `edit` holds even with `--auto`.
- `--variant <high|max|minimal>` sets provider-specific reasoning effort when supported.
