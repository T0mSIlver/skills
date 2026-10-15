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
| [`owner-charter`](owner-charter/SKILL.md) | The owner's rules for every repo: what they decide on a card before any code, how to ask, what must hold before a merge, and what they reject |
| [`intent-card`](intent-card/SKILL.md) | Asks the owner before code on one card: one question, two shapes designed in from the start and a pick, shown in the lightest medium (mockup, video, prototype). Adapted from pstack's `architect` |
| [`blast-radius`](blast-radius/SKILL.md) | Before ready, what a change could break beyond its diff, visually and functionally per platform, the one fact it's safe because of, and the cheapest proof per risk, as the PR body's Blast radius section. Adapted from pstack |
| [`verify`](verify/SKILL.md) | A second agent checks a PR before merge: blast radius, intent, evidence it looked at, peers on the same screen, a baseline on main for bug fixes, then VERIFIED, NOT VERIFIED or INCONCLUSIVE with scope. Adapted from pstack |
| [`correct`](correct/SKILL.md) | A correction made twice, or a finding seen twice, becomes the highest check that catches it (type, lint, test, verifier rule, doc), proven to fail on the past mistake, in a rule → check table. Adapted from pstack |
| [`debt-review`](debt-review/SKILL.md) | Weekly: reads the week's merged PRs, finds second ways, bolt-ons, dead code and workarounds, and proposes a redesign from first principles for each, one owner card each. Adapted from pstack |
| [`cross-review`](cross-review/SKILL.md) | Review of a committed change by another vendor's model, launched before CI and the PR body so it runs while they do, with a rubric that keeps false positives down |
| [`orchestrate-sessions`](orchestrate-sessions/SKILL.md) | Runs one desktop session as the scheduler for many: starts a session per issue, briefs each one, takes handoffs, and archives finished sessions |
| [`merge-queue`](merge-queue/SKILL.md) | Merges parallel PRs without breaking main: checks each against commits that landed after its CI run, builds the combination when they overlap, stacks PRs that share files |
| [`scarce-resource`](scarce-resource/SKILL.md) | Books a shared runner or GPU into the owner's night window, one dispatch at a time, with wake-ups that fire while the session is idle |
| [`quota`](quota/SKILL.md) | What each usage window means, which model spends it, and a queue that fills every Codex window before it resets |
| [`claude-remote-control-server`](claude-remote-control-server/SKILL.md) | A `claude remote-control` server per repo, run as a systemd service so it's always up |
| [`unnarrate`](unnarrate/SKILL.md) | Deletes text that narrates itself: comments that repeat the code, tooltips that repeat the label, PR bullets that repeat the diff |
| [`docs-review`](docs-review/SKILL.md) | Edits a project's docs: checks each claim against the code, keeps each fact on one page and each behaviour in one sentence, and trims |
| [`test-audit`](test-audit/SKILL.md) | A gate for new tests and an audit for deleting low-value ones: tests of mocks, mirrored expected values, duplicate coverage |
| [`unslop`](unslop/SKILL.md) | Vendored from [cursor/plugins](https://github.com/cursor/plugins). Removes AI tells from prose |
| [`herdr`](herdr/SKILL.md) | Vendored from [herdrdev/herdr](https://github.com/herdrdev/herdr). Controls panes and other agents inside herdr |
| [`gh-stack`](gh-stack/SKILL.md) | Vendored from [github/gh-stack](https://github.com/github/gh-stack). Stacked branches and PRs with the `gh stack` extension |
| [`starbridge`](starbridge/SKILL.md) | Vendored from [T0mSIlver/starbridge](https://github.com/T0mSIlver/starbridge). Asks the owner on their phone, through the Starbridge app, and reports runs that block them |
| [`fastcontext`](fastcontext/SKILL.md) | Read-only repo exploration on a local model. Turned off on my machine because the GPU has other jobs |

## Why it's built this way

- **Sessions instead of native subagents.** A spawned session treats the
  prompt as coming from its user and gets on with it. A native subagent stops
  to ask a user who isn't there. Every session can be resumed, read, watched,
  or handed to another session partway through, and each task can use a
  different model and harness. One scheduler session orchestrates the others,
  through Claude Code's session messaging or through herdr.
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
agent's skills folder. [docs/vendoring.md](docs/vendoring.md) explains how
the vendored skills stay pinned to upstream.

MIT. Each vendored skill keeps its upstream license, and each skill adapted
from pstack carries pstack's MIT notice in its `LICENSE`.
