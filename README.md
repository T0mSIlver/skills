# skills

The [Agent Skills](https://agentskills.io) I use with Claude Code, Codex,
opencode and pi. I wrote some of them. The others are copied unchanged from
their upstream repos.

A skill stays only while it tells the model something the model would get
wrong without it. That is why most of these are gotchas backed by evidence
rather than tutorials. When upstream fixes what a skill works around, I delete
the skill.

## Five to start with

These five work in any repo. `verify` and `blast-radius` mention the owner
charter and intent cards from the rest of this repo, and work without them.
`verify` uses the `gh` CLI. Each
install line puts one skill in Claude Code (2.1.275 or later). For Codex,
opencode, Cursor and the other agents, use `npx skills add T0mSIlver/skills
--skill <name>`.

**[`test-audit`](test-audit/SKILL.md)** decides which tests are worth having:
four questions before any new test, and an audit for deleting tests that
mirror the code, test mocks or repeat stronger coverage. The day after it
merged, five agents ran it over five areas of localvoxtral's tests, and each
deletion names the test that still proves its contract: 1,586 lines out and
838 in, test code only
([#947](https://github.com/T0mSIlver/localvoxtral/pull/947) to
[#951](https://github.com/T0mSIlver/localvoxtral/pull/951)). It has the
most installs of anything here.

```text
/plugin install test-audit --marketplace T0mSIlver/skills
```

**[`blast-radius`](blast-radius/SKILL.md)** writes what a change could break
beyond its diff, on each platform and on screen, the one fact it is safe
because of, and the cheapest proof for each risk. It exists because icons
that sat low or off-centre, on desktop, web and Android, passed review four
times
([#1453](https://github.com/T0mSIlver/starbridge/pull/1453),
[#1477](https://github.com/T0mSIlver/starbridge/pull/1477),
[#1564](https://github.com/T0mSIlver/starbridge/pull/1564),
[#1713](https://github.com/T0mSIlver/starbridge/pull/1713)): reviewers read
the diff, and nobody listed the icon beside its neighbours as a surface.
167 merged Starbridge PRs carry a Blast radius section.

```text
/plugin install blast-radius --marketplace T0mSIlver/skills
```

**[`verify`](verify/SKILL.md)** has a second agent, not the author, check a
PR before merge. It reads the PR's blast radius, gathers evidence risk by
risk, opens every screenshot itself, reproduces a bug on main before
accepting the fix, and argues against its own verdict before posting
VERIFIED, NOT VERIFIED or INCONCLUSIVE. It expects a Blast radius section,
so install it with `blast-radius`.

```text
/plugin install verify --marketplace T0mSIlver/skills
```

**[`docs-review`](docs-review/SKILL.md)** edits a project's docs: every
claim checked against the code, one page per fact, one sentence per
behaviour, then a trim. Each rule is a correction reviewers made more than
once on Starbridge's docs ([sources](docs-review/reference/sources.md)). The
pass those rules came from cut the docs by a third, 9,055 to 6,119 in the
PR's count
([#1273](https://github.com/T0mSIlver/starbridge/pull/1273)).

```text
/plugin install docs-review --marketplace T0mSIlver/skills
```

**[`unnarrate`](unnarrate/SKILL.md)** deletes text that narrates itself:
comments that repeat the next line, tooltips that repeat the label, PR
bullets that repeat the diff. Run it before
[`unslop`](unslop/SKILL.md), which fixes how the remaining sentences sound.

```text
/plugin install unnarrate --marketplace T0mSIlver/skills
```

On Claude Code before 2.1.275, add the marketplace first with
`/plugin marketplace add T0mSIlver/skills`, then
`/plugin install <name>@t0msilver-skills`.

## All of them

The rest are built around how I work: one owner, many agent sessions, a
phone app for decisions. They are here to read and adapt.

| Skill | What it gives the agent |
|-------|-------------------------|
| [`owner-charter`](owner-charter/SKILL.md) | The owner's rules for every repo: what they decide on a card before any code, how to ask, what must hold before a merge, and what they reject |
| [`intent-card`](intent-card/SKILL.md) | Asks the owner before code on one card: one question, two shapes designed in from the start and a pick, shown in the lightest medium (mockup, video, prototype). Adapted from pstack's `architect` |
| [`blast-radius`](blast-radius/SKILL.md) | Before ready, what a change could break beyond its diff, visually and functionally per platform, the one fact it's safe because of, and the cheapest proof per risk, as the PR body's Blast radius section. Adapted from pstack |
| [`verify`](verify/SKILL.md) | A second agent checks a PR before merge: blast radius, intent, evidence it looked at, peers on the same screen, a baseline on main for bug fixes, then VERIFIED, NOT VERIFIED or INCONCLUSIVE with scope. Adapted from pstack |
| [`evidence-bundle`](evidence-bundle/SKILL.md) | What an agent proves before the owner sees its PR or draft (tests on the pushed head, renders, claims against sources, a fresh refuter, cross-review), in one PR comment with a trust level that says whether the agent merges or the owner decides |
| [`correct`](correct/SKILL.md) | A correction made twice, or a finding seen twice, becomes the highest check that catches it (type, lint, test, verifier rule, doc), proven to fail on the past mistake, in a rule → check table. Adapted from pstack |
| [`debt-review`](debt-review/SKILL.md) | Weekly: reads the week's merged PRs, finds second ways, bolt-ons, dead code and workarounds, and proposes a redesign from first principles for each, one owner card each. Adapted from pstack |
| [`cross-review`](cross-review/SKILL.md) | Review of a committed change by another vendor's model, launched before CI and the PR body so it runs while they do, with a rubric that keeps false positives down |
| [`orchestrate-sessions`](orchestrate-sessions/SKILL.md) | Runs one desktop session as the scheduler for many: starts a session per issue, briefs each one, takes handoffs, and archives finished sessions |
| [`merge-queue`](merge-queue/SKILL.md) | Merges parallel PRs once each is checked (intent, CI, review, blast radius, verifier verdict) without breaking main: checks each against commits that landed after its CI run, builds the combination when they overlap, stacks PRs that share files, and merges merge-by-default PRs without the owner once the proof verdict says sufficient |
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

[docs/install.md](docs/install.md) covers the plugin names, what each skill
needs installed, and the hook that installs the owner workflow in every
session of a repo, cloud sessions included. My own machines don't use either command: they run
[a sync loop](docs/sync-system.md) that installs `origin/main` into every
agent's skills folder. [docs/vendoring.md](docs/vendoring.md) explains how
the vendored skills stay pinned to upstream.

MIT. Each vendored skill keeps its upstream license, and each skill adapted
from pstack carries pstack's MIT notice in its `LICENSE`.
