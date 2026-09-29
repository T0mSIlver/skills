# Repo config

The `orch-*` scripts source `~/.config/orchestrate/<repo-name>.env`, where
`<repo-name>` is the last part of the current checkout's `origin` URL.
`ORCH_CONFIG=<path>` overrides it. Keep the file in the owner's dotfiles, so
a successor on the same machine finds it.

The file holds only what the scripts need. The owner's rules, the night
plan and the ledger belong in the project memory; the repo's CI rules belong
in its agent guide.

| Variable | Meaning | Example |
|---|---|---|
| `REPO` | owner/name | `T0mSIlver/localvoxtral` |
| `BASE` | branch PRs merge into | `main` |
| `GATE_CHECKS` | check runs that must pass (or skip) on the head before a merge | `build-test linux mac-lanes` |
| `MUST_RUN_CHECKS` | gate checks whose skip doesn't count, such as a self-hosted job that skips drafts | `mac-lanes` |
| `OPTIONAL_CHECKS` | checks that may be absent but block when red | `dogfood` |
| `COMBO_CHECKS` | checks a combo draft runs (hosted only) | `build-test linux` |
| `CI_WORKFLOW_NAME` | workflow whose run time dates the PR's test | `CI` |
| `CODE_PATHS` | regex of paths whose overlap needs a combo check | `^(Sources\|Tests\|scripts)/` |
| `WAITS_PREFIX` | label prefix that blocks a merge | `waits:` |
| `STACK_LABEL` | label of a PR stacked on another | `waits:stack` |
| `MERGE_METHOD` | `squash`, `merge` or `rebase` | `squash` |
| `LAG_MINUTES` | how far before the CI run to count landings | `30` |
| `RESOURCE_JOBS` | job names `orch-idlewait` waits on (default `MUST_RUN_CHECKS`) | `mac-lanes eval-e2e` |
| `POLL_SECONDS` | poller interval; stay at one GitHub call a minute or less per PR | `180` |
| `LANE_STEPS` | jq regex of the must-run job's step names that `orch-lanecheck` prints | `Integration tests \\(live STT\|Live herdr` |
| `WAIVER_PATTERN` | grep -E pattern of lane waivers in PR bodies | `\[skip-[a-z-]*: [^]]*\]` |

## Where repo-specific knowledge goes

- **This config:** what the scripts need.
- **Project memory** (auto-loaded in every session on the repo): the owner's
  standing rules (merge classes, windows, who may do what), the night plan,
  the ledger of sessions and bookings, CI failure signatures.
- **The repo's agent guide:** rules every worker follows (claiming issues,
  proof, lanes, markers). If a rule applies to workers and not only to the
  scheduler, it belongs there.
- **Handoff comments on PRs:** what one PR still needs.
