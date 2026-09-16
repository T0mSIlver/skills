# Installing

Each skill is a plain [Agent Skills](https://agentskills.io/specification)
folder, so any tool that reads SKILL.md files can load it.

**`skills` CLI** (installs into Claude Code, Codex, opencode, Cursor, and
[many others](https://github.com/vercel-labs/skills)):

```bash
npx skills add T0mSIlver/skills                               # pick interactively
npx skills add T0mSIlver/skills -a claude-code -a codex -g -y # everything, globally
```

**Claude Code plugin marketplace:**

```text
/plugin marketplace add T0mSIlver/skills
/plugin install cli-delegation@t0msilver-skills    # delegate-to-*, fastcontext
/plugin install claude-rc-server@t0msilver-skills  # claude-remote-control-server
/plugin install unnarrate@t0msilver-skills
/plugin install vendored@t0msilver-skills          # unslop, herdr, gh-stack
```

**Manual:** copy a top-level skill directory into your agent's skills folder
(`~/.claude/skills/`, `~/.codex/skills/`, `~/.config/opencode/skills/`,
`~/.pi/agent/skills/`, …).

## What the folder copy doesn't install

Neither install method runs scripts. Skills that need more than their folder
list the requirement in their `compatibility:` frontmatter:

- `fastcontext` needs the
  [fastcontext CLI](https://github.com/T0mSIlver/fastcontext#installation) on
  `PATH` and a model server for it. If the CLI is missing, the skill says so
  when it loads.
- `claude-remote-control-server` creates a user systemd service with its
  `scripts/install-claude-rc-server-service.sh`. The agent runs that script
  during setup, not at install time. The script also enables a shared timer
  that restarts servers still running an old CLI after an auto-update.
- `delegate-to-claude-code` works best with `scripts/claude-rc-spawn` (needs
  `tmux`) on `PATH`, which starts sessions you can watch remotely. Plain
  `claude -p` works without it.
- `gh-stack` needs the [gh-stack](https://github.com/github/gh-stack) `gh`
  extension.
- `delegate-to-*` each need their CLI installed and logged in.

## Turning skills off on one machine

With the [sync loop](sync-system.md), `skills-toggle` keeps a skill off one
machine, for one agent or for all of them, without changing the repo:

```bash
skills-toggle list                          # skill-by-agent grid
skills-toggle disable fastcontext           # off for every agent here
skills-toggle enable fastcontext --agent codex
skills-tui                                  # the same grid, interactive
```
