# Vendoring skills from other repositories

Some skills in this repo are not written here — they are **pristine copies** of
skills published in other repositories, imported verbatim so the install rails
(`npx skills add`, the plugin marketplace, the sync timer) carry them like any
other skill.

Pristine means exactly that: **never patch a vendored directory in-tree.** The
next update overwrites it and your fix disappears. Send the fix upstream; the
daily update PR brings it back.

Vendored today:

| Skill | Upstream | License |
|-------|----------|---------|
| [`unslop`](../unslop/SKILL.md) | [`cursor/plugins`](https://github.com/cursor/plugins) `pstack/skills/unslop` | MIT, Lauren Tan |
| [`grilling`](../grilling/SKILL.md) | [`mattpocock/skills`](https://github.com/mattpocock/skills) `skills/productivity/grilling` | MIT, Matt Pocock |
| [`grill-me`](../grill-me/SKILL.md) | [`mattpocock/skills`](https://github.com/mattpocock/skills) `skills/productivity/grill-me` | MIT, Matt Pocock |
| [`grill-with-docs`](../grill-with-docs/SKILL.md) | [`mattpocock/skills`](https://github.com/mattpocock/skills) `skills/engineering/grill-with-docs` | MIT, Matt Pocock |
| [`domain-modeling`](../domain-modeling/SKILL.md) | [`mattpocock/skills`](https://github.com/mattpocock/skills) `skills/engineering/domain-modeling` | MIT, Matt Pocock |

## The moving parts

- `vendor.toml` — the manifest: one `[[skills]]` table per vendored skill, with
  the upstream `repo`, `ref`, `path`, `license` path, and the pinned `commit`.
- `scripts/vendor-skills.sh` — clones each upstream at its `ref`, copies
  `path/` into `./<name>/`, drops the upstream license at `./<name>/LICENSE`,
  writes the `./<name>/.vendored` stamp, and bumps `commit` in the manifest.
- `.github/workflows/vendor-skills.yml` — runs the script daily and opens one
  PR per skill that moved.

## Adding an upstream

1. Add a `[[skills]]` table to `vendor.toml`. Leave `commit` as all zeros —
   the first run resolves it.

   ```toml
   [[skills]]
   name = "some-skill"
   repo = "https://github.com/owner/repo"
   ref = "main"
   path = "path/to/the/skill"
   license = "LICENSE"
   commit = "0000000000000000000000000000000000000000"
   ```

2. Vendor it and eyeball what landed:

   ```bash
   scripts/vendor-skills.sh --only some-skill
   uvx --from skills-ref==0.1.1 agentskills validate ./some-skill
   ```

3. Add the directory to the `vendored` plugin's `skills` list in
   `.claude-plugin/marketplace.json`, list it in the table above and in the
   README, then commit the manifest, the skill directory, and the stamp
   together.

## Flags

| Flag | Does |
|------|------|
| *(none)* | Vendor every manifest entry that moved upstream |
| `--only <name>` | Restrict everything to one entry |
| `--check` | Report stale pins, write nothing, exit 1 if any are stale |
| `--verify` | Offline consistency check: manifest ⇄ `.vendored` stamps |
| `--force` | Re-copy even when the pin is already current |
| `--summary <file>` | Write the markdown update report used as the PR body |

`--verify` runs in `validate.yml`. `--check` deliberately does not: it needs the
network and goes red whenever an upstream repo moves, which is the update
workflow's job to resolve, not a reason to block an unrelated PR.

## The update PR

`vendor-skills.yml` runs at 06:17 UTC daily, and on demand via
**workflow_dispatch** (optional `only` input). A first job reads the manifest
and fans out one matrix job per skill; each re-vendors its own skill and, if
anything changed, opens or updates a PR on branch `vendor/<name>` titled
`vendor: update <name> to <short sha>`, labelled `vendor`. The body carries the
old→new SHA, a GitHub compare link, and the upstream commits that touched the
vendored path.

Review it as an import, not as a diff to fix: read the upstream changes, then
merge or close. If something is wrong with the skill, the fix belongs in a PR to
the upstream repo.

**`VENDOR_PR_TOKEN` must be set** to a PAT with `contents: write` and
`pull_requests: write`. The workflow falls back to `GITHUB_TOKEN`, but GitHub
does not trigger `pull_request` workflows for anything pushed with that token —
`validate.yml` would never run on the bot's PR, and the vendored skill would
land unvalidated. The `vendor` label must also exist in the repo
(`gh label create vendor --color 0E8A16`); the action does not create it.

## Gotchas

- A directory that exists without a `.vendored` stamp is never touched: the
  script refuses rather than clobber a hand-written skill that happens to share
  a name.
- The upstream `LICENSE` is only copied in if the vendored path does not already
  ship one, so an upstream per-skill license always wins.
- The PR body's commit range needs upstream history. The clone is shallow and
  deepened by 200 commits (`VENDOR_DEEPEN`); a pin older than that, or a
  force-pushed ref, degrades to "history unavailable" — the update itself still
  happens.
- The sync timer ([docs/sync-system.md](sync-system.md)) deploys vendored skills
  like any other, hold-on-local-edit included — but a `skills-pr` PR against a
  vendored directory patches a pristine copy. Discard it with
  `skills-pr --discard <skill>` and send the fix upstream instead.
- Editing `commit` in `vendor.toml` by hand desynchronises it from the stamp and
  turns `--verify` (and therefore CI) red. Run the script instead.
- The spec validator (`skills-ref`) rejects frontmatter keys it does not know,
  but upstream skills legitimately use Claude Code extensions such as
  `disable-model-invocation`. CI validates through
  `scripts/validate-skills.py`, which adds Claude Code's documented keys to the
  validator's allowlist. A new key that is really in Claude Code's frontmatter
  reference goes into `CLAUDE_CODE_FIELDS` there, not into the vendored skill.

## Not possible

- Local patches on top of an upstream skill. There is no patch series and no
  three-way merge — the update is `rm -rf` plus a fresh copy. If you need a
  changed version, fork it upstream and point `repo` at your fork.
- Vendoring a subdirectory that is not a complete skill. The copied directory
  must contain its own `SKILL.md`, because `validate.yml` and the sync timer
  both discover skills by that file.
