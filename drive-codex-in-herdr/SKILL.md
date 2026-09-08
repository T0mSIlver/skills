---
name: drive-codex-in-herdr
description: How to bound a codex agent started in a herdr pane with `herdr agent start --kind codex` — the sandbox flags that hold, and the approval that escapes them. Use alongside the `herdr` skill for interactive, multi-turn, or approval-gated edit work. Read-only review and any one-shot run belongs in delegate-to-codex instead.
compatibility: Requires the herdr and codex CLIs and this agent running inside a herdr-managed pane (HERDR_ENV=1).
---

# Drive Codex in herdr

[`herdr`](../herdr/SKILL.md) drives the CLI itself.
[`delegate-to-codex`](../delegate-to-codex/SKILL.md) runs anything read-only or
one-shot headlessly, which is most work. Use a pane only when the work is
interactive, multi-turn, or approval-gated — and bound it:

```bash
herdr agent start worker --kind codex --pane <pane-id> -- -s workspace-write -a never
```

- **Always pass `-s`.** Without it codex inherits
  `sandbox_mode = "danger-full-access"` from `~/.codex/config.toml`.
- **`-a never` is what makes `-s` real.** Under `-a on-request` an approved
  command runs *outside* the sandbox — the dialog says `Environment: local`, and
  one `enter` let a `read-only` worker write a file. Evidence:
  `reference/gotchas.md`.
