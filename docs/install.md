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
/plugin install owner-workflow@t0msilver-skills    # owner-charter and the skills that carry it out
/plugin install cli-delegation@t0msilver-skills    # cross-review, fastcontext
/plugin install remote-control-server@t0msilver-skills  # claude-remote-control-server
/plugin install unnarrate@t0msilver-skills
/plugin install test-audit@t0msilver-skills
/plugin install docs-review@t0msilver-skills
/plugin install blast-radius@t0msilver-skills
/plugin install verify@t0msilver-skills       # pairs with blast-radius
/plugin install orchestrate-sessions@t0msilver-skills
/plugin install vendored@t0msilver-skills          # unslop, herdr, gh-stack
```

`owner-workflow` already contains `blast-radius` and `verify`. Install it or
the two single plugins, not both, or each skill loads twice.

**Manual:** copy a top-level skill directory into your agent's skills folder
(`~/.claude/skills/`, `~/.codex/skills/`, `~/.config/opencode/skills/`,
`~/.pi/agent/skills/`, …).

## In every session of a repo, cloud sessions included

Cloud sessions install no plugins, even ones a repo enables in its
settings; they get the repo's own `.claude/` hooks and skills. So a repo
that wants the owner workflow in every session, on any machine, runs
`scripts/install-skills.sh` when a session starts. Add this to the repo's
`.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "curl -fsSL https://raw.githubusercontent.com/T0mSIlver/skills/main/scripts/install-skills.sh | bash > /dev/null"
          }
        ]
      }
    ]
  }
}
```

It copies the owner workflow and the skills it relies on (`owner-charter`,
`intent-card`, `blast-radius`, `verify`, `correct`, `debt-review`,
`cross-review`, `starbridge`, `unslop`, `unnarrate`, `docs-review`,
`test-audit`) into `~/.claude/skills`, where the session finds them at once.
It fetches each file from `main` on raw.githubusercontent.com, following
`scripts/install-skills.list`, because a cloud session's GitHub proxy
refuses archive downloads. A skill already there that the script didn't write,
such as one the [sync loop](sync-system.md) installed, is left alone; when
every skill came from elsewhere it downloads nothing. Its own copies are
refreshed at each session start and resume. Name skills after
`bash -s --` to install others.

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
- `orchestrate-sessions` works only in the Claude Code desktop app, whose
  session tools (`spawn_task`, `send_message`, `archive_session`, …) it uses.
- `gh-stack` needs the [gh-stack](https://github.com/github/gh-stack) `gh`
  extension.
- `cross-review` needs opencode or Codex installed and logged in.

## Turning skills off on one machine

With the [sync loop](sync-system.md), `skills-toggle` keeps a skill off one
machine, for one agent or for all of them, without changing the repo:

```bash
skills-toggle list                          # skill-by-agent grid
skills-toggle disable fastcontext           # off for every agent here
skills-toggle enable fastcontext --agent codex
skills-tui                                  # the same grid, interactive
```
