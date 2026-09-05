# Deploying these skills with the sync timer

This is the author's own deployment loop for keeping the same skill versions
live across Claude Code, Codex, opencode, and pi on a machine. It is **optional** —
`npx skills add T0mSIlver/skills` or the Claude Code plugin marketplace are the
supported ways to consume the repo. Use this system if you want skills that
update themselves from `origin/main` and a one-command path for upstreaming
fixes an agent makes to an installed copy.

| Location | Serves |
|----------|--------|
| `~/.claude/skills/` | Claude Code (native) |
| `~/.codex/skills/` | Codex (native) |
| `~/.config/opencode/skills/` | opencode (native) |
| `~/.pi/agent/skills/` | pi (native) |

Install the user-level timer:

```bash
scripts/install-sync-timer.sh
```

The timer runs every 2 minutes. Each run fetches `origin/main`, exports that
fetched tree into a temporary directory, and then syncs every top-level
directory containing a `SKILL.md` into the four native locations. If GitHub
fetching fails because credentials or the network are unavailable, the sync
still updates the native folders from the current local checkout. It updates
only skills managed by this repo and leaves unrelated local skills alone. It
also installs skill-managed helper commands, such as `claude-rc-spawn` and
`install-claude-rc-server-service.sh`, into `~/.local/bin`.

The repo is the source of truth, but **local edits win**. The sync hashes each
installed skill against the state it wrote last time (`.skills-sync-state`), and
a skill whose installed copy was edited in place is *held* — never overwritten.
A hold ends in one of three ways:

- The edits land on `origin/main` merged as-is, and the sync reconverges quietly.
- Upstream changes the skill while it is held — the PR was merged with
  modifications, say. The reviewed upstream version wins and replaces the local
  edits, and a one-shot copy of them is kept in `/tmp` and named in the journal.
- The edits are discarded explicitly with `skills-pr --discard`.

While a hold lasts, the sync stays quiet rather than noisy:

- Each destination gets a `README.md` saying the directory is managed, where
  the content comes from (remote, branch, commit), when it last synced, and
  which skills are currently held because of local edits.
- The first sync that sees a local edit logs one `NOTICE: local edits in …`
  journal line with the exact next steps, then stays quiet while the hold
  lasts.
- "synced" journal lines only appear when a skill's content actually changed,
  so notices stand out instead of drowning in no-op noise.

## Turning a skill off on one machine

An agent stops offering a skill only when the skill's file is gone. Blocking it
some other way — a Claude Code `permissions.deny` rule, for instance — stops it
from running but still injects its description into every session, so it keeps
costing context and keeps tempting the model. Deleting the directory by hand
does not last either: the next sync, at most two minutes later, reinstalls it.

So the sync itself owns the off switch, and disabled means **not installed**:

```bash
skills-toggle list                          # the skill-by-agent grid
skills-toggle disable fastcontext           # off for every agent
skills-toggle enable fastcontext --agent codex
skills-toggle edit                          # hand-edit the rules, then apply
```

Rules live in `~/.config/skills-sync/disabled`, which is machine-local and
never synced — the skill stays in the repo and on the remote, and other
machines are unaffected. One rule per line:

```text
fastcontext                       # off for every agent
claude:delegate-to-claude-code    # off for Claude Code only
codex:claude-remote-control-server
```

`skills-tui` is the same grid, interactive — arrows or `hjkl` to move, space
to toggle a cell, `a` for a whole row, `w` to apply, `q` to quit. It is Python
stdlib `curses` only, so it runs anywhere the sync does.

```text
skills — on/off per agent, this machine only
space toggle · a row · w apply · r reload · q quit

SKILL                          claude    codex    opencode    pi
claude-remote-control-server     on        off       off       off
delegate-to-claude-code          off       on        on        on
fastcontext                      off*      on        on        on

1 unapplied change — w to apply · rules: ~/.config/skills-sync/disabled
```

`skills-toggle` runs the sync as soon as it writes a rule, so a toggle takes
effect immediately rather than on the next timer tick — unless the timer's own
sync is mid-run, in which case it says so and the rule lands on the next tick
instead of claiming to have applied. Disabling a skill that was *held* for
local edits preserves those edits the same way an upstream removal does: a
copy goes to `/tmp`, and both tools print the path rather than leaving it in
the journal only.

A disable removes what the sync installed. A directory the sync did *not*
install — a destination pre-populated before its first sync, or one recreated
by hand — is left alone, because it is not the repo's to delete; the sync
warns on every run and names it in the destination's `README.md`, since the
agent does still load it.

`skills-pr` ignores destinations where a skill is absent, so a disabled skill
is never mistaken for one you deleted and never turns into a PR.

## Upstreaming a fix found while using a skill

An in-place edit to an installed copy is almost always an agent that spotted a
mistake mid-task. The intended flow is: edit the installed copy, open a PR
with one command, and **ask the repo owner to review it** — the local edit
stays live (held) in the meantime, and everything reconverges on merge.
`skills-pr` is installed into `~/.local/bin` by the sync:

```bash
# after editing the installed copy in place:
skills-pr -m "delegate-to-codex: fix resume example"
# ... then tell the owner to review the PR it prints.

# preview without pushing or opening a PR:
skills-pr --dry-run

# throw the local edits away and reinstall the repo version:
skills-pr --discard delegate-to-codex
```

It diffs the installed copies against `origin/main`, applies the drift in a
temporary worktree of the repo checkout (found via the `.skills-sync-repo`
breadcrumb each destination carries), commits, pushes a `skills-pr/...`
branch, opens the PR with `gh`, and prints the review-request next step. The
destination `README.md` and the sync's `NOTICE` journal line teach the same
two commands, so an agent whose skill is held is told the path in the same
breath.

For private GitHub repos, the timer needs noninteractive git credentials. The
installer imports currently available `GITHUB_TOKEN`, `GH_TOKEN`, and
`SSH_AUTH_SOCK` values into the user systemd manager without writing them to the
unit file.

## Useful commands

```bash
scripts/sync-skills.sh
skills-pr --dry-run
skills-pr --discard <skill>
skills-toggle list
skills-toggle disable <skill> [--agent claude|codex|opencode|pi]
skills-tui
install-claude-rc-server-service.sh
systemctl --user status skills-sync.timer
systemctl --user status claude-rc-skills.service
journalctl --user -u skills-sync.service -n 80 --no-pager
journalctl --user -u claude-rc-skills.service -n 80 --no-pager
```
