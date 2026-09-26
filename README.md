# skills

The [Agent Skills](https://agentskills.io) I use with Claude Code, Codex,
opencode and pi. I wrote some of them. The others are copied unchanged from
their upstream repos.

A skill stays only while it tells the model something the model would get
wrong without it. That is why most of these are gotchas backed by evidence
rather than tutorials. When upstream fixes what a skill works around, I delete
the skill.

| Skill | What it gives the agent |
|-------|-------------------------|
| [`delegate-to-codex`](delegate-to-codex/SKILL.md) | Review and edit runs through `codex exec`, including the stdin wedge and the sandbox that `resume` drops |
| [`delegate-to-opencode`](delegate-to-opencode/SKILL.md) | The same for GLM through `opencode run`, with the agent configs that flags can't express |
| [`delegate-to-claude-code`](delegate-to-claude-code/SKILL.md) | The same for `claude`, as sessions I can watch and steer from claude.ai/code |
| [`cross-review`](cross-review/SKILL.md) | Review of a committed change by another vendor's model, launched before CI and the PR body so it runs while they do, with a rubric that keeps false positives down |
| [`claude-remote-control-server`](claude-remote-control-server/SKILL.md) | A `claude remote-control` server per repo, run as a systemd service so it's always up |
| [`unnarrate`](unnarrate/SKILL.md) | Deletes text that narrates itself: comments that repeat the code, tooltips that repeat the label, PR bullets that repeat the diff |
| [`unslop`](unslop/SKILL.md) | Vendored from [cursor/plugins](https://github.com/cursor/plugins). Removes AI tells from prose |
| [`herdr`](herdr/SKILL.md) | Vendored from [herdrdev/herdr](https://github.com/herdrdev/herdr). Controls panes and other agents inside herdr |
| [`gh-stack`](gh-stack/SKILL.md) | Vendored from [github/gh-stack](https://github.com/github/gh-stack). Stacked branches and PRs with the `gh stack` extension |
| [`test-audit`](test-audit/SKILL.md) | Vendored from [openclaw/openclaw](https://github.com/openclaw/openclaw). A gate for new tests and an audit for low-value ones |
| [`fastcontext`](fastcontext/SKILL.md) | Read-only repo exploration on a local model. Turned off on my machine because the GPU has other jobs |

## Why it's built this way

- **Other CLIs instead of native subagents.** A spawned CLI session treats the
  prompt as coming from its user and gets on with it. A native subagent stops
  to ask a user who isn't there. Every session can be resumed, read, watched,
  or handed to another session partway through, and each task can use a
  different model and harness. The price is that I run the orchestration
  myself.
- **Another model reviews the code.** I don't read agent output line by line.
  A model from another vendor, in another harness, reviews the diff, and I act
  on what it finds.
- **The machine is the sandbox.** Agents run with full permissions on a box
  that exists for them. Worktrees stop agents from overwriting each other's
  files. The machine is the only security boundary.

## Install

```bash
npx skills add T0mSIlver/skills                  # choose skills interactively
```

```text
/plugin marketplace add T0mSIlver/skills         # Claude Code
```

[docs/install.md](docs/install.md) covers the plugin names and what each skill
needs installed. My own machines don't use either command: they run
[a sync loop](docs/sync-system.md) that installs `origin/main` into every
agent's skills folder. [docs/delegation.md](docs/delegation.md) has the rules
the `delegate-to-*` skills share, and [docs/vendoring.md](docs/vendoring.md)
explains how the vendored skills stay pinned to upstream.

MIT. Each vendored skill keeps its upstream license.
