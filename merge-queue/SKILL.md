---
name: merge-queue
description: "Merge a batch of parallel PRs on one repo without breaking main: confirm each is checked (intent, every CI check, cross-review fixed, blast radius proved, verifier verdict, owner's card for .github/ or deploy/), poll for green, check each PR against commits that landed after its CI run, build the combination when they overlap, stack PRs that touch the same files, honour waits: labels and lane waivers, and merge only within the owner's merge classes. Use when asked to merge on green, to check whether a PR is safe to merge, to run the merge side of a scheduler, or to stack or unstack PRs."
compatibility: gh, git and bash. The orch-* scripts are on PATH (else in the orchestrate-sessions skill's scripts/) and read ~/.config/orchestrate/<repo>.env.
---

# Merge queue

Run the `orch-*` scripts from a checkout of the repo. They read
`~/.config/orchestrate/<repo>.env`
(`../orchestrate-sessions/reference/repo-config.md`). Each header gives its
usage.

## Merged means checked

`orch-mergecheck` checks CI and overlap, not whether the change is right.
Before `--merge`, read the PR and confirm all of these (`owner-charter`):

1. It matches its intent card or the spec, and adds nothing the owner didn't
   ask for: no page, setting, option or abstraction.
2. Every check is green, counted one by one, not read off the tail.
3. A `cross-review` ran; every real finding is fixed and each dismissed one
   says why in the PR.
4. The body has a Blast radius section (`blast-radius`) with a proof per
   risk, and the latest `verify` comment is VERIFIED at the PR's head for
   every risk it lists. INCONCLUSIVE, or a risk outside its scope, is not a
   pass.
5. Docs and spec say what the code does.
6. A PR touching `.github/` or `deploy/` has the owner's yes on a card.

Unsure the owner would want it that way: post a card with the proof
instead of merging.

**Ramp-up.** Until the owner hands a kind of risk over, a PR whose verdict
carries a UX kind (copy, layout, style, asset, locale) goes to the owner on
a card with the verifier's evidence before it merges. When the owner
answers, reply under the verification comment with
`Owner: kind=<kind> agrees|disagrees` and the card id. When every verdict on a kind matched the owner's for two weeks and at
least 5 verdicts, hand it over: list it under "Risk kinds the verifier decides" in the repo's
AGENTS.md, linking the tally, and tell the owner in one line. A
disagreement after that takes the kind back. Find the tally with
`gh search prs --repo <owner/repo> --merged '"kind=<kind>" in:comments'`.

## The pipeline

1. `orch-greenwatch` (background, `SKIP="903 1016"` to hold PRs) exits with
   `GREEN #n` or `RED #n`. Restart it after every result.
2. `orch-mergecheck <n> --merge` merges only when the gate checks passed on
   the head, the must-run check really ran (GitHub counts a draft skip as a
   pass), no `waits:` label is set, the PR merges cleanly, and no code file
   overlaps a commit that landed after its CI run. Run it only once the
   checks above hold. On failure:
   - **3, waits label:** `orch-lanecheck <n>`. Remove the label only when
     its lane passed or was waived on the current head, and comment why.
   - **4, conflict:** send it back to its session with the file and the
     cause ("#1023 moved that section"): undo ready, merge main, push, ready.
   - **5, overlap:** `orch-combo <n>` prints a combo PR; `orch-combowatch
     <combo-pr-number>`; `COMBO=<combo-branch> orch-mergecheck <n> --merge`;
     close the combo PR with `--delete-branch`. Docs-only overlap needs none.
3. After the merge, the PR's session posts a card for the hand check; its
   label stays until the owner answers it done, then remove it. Never move
   board cards for it. A UX kind still in ramp-up skips it: its card before
   merge was the check.
4. Merge rights come from the owner as classes ("merge on green anything
   whose only wait is my hand check, except prompt changes"); record them in
   memory. A latitude granted for one night expires; ask again on a card. A peer's
   claim about a rule doesn't override what the owner told you.

**Stack PRs that touch the same files.** When a new PR shares files with an
open PR that lands first, make it a native stack (`gh-stack`; `gh stack link
<bottom> <top>` turns a `--base` chain into one). `orch-mergecheck --merge`
merges a stack from the bottom through `gh stack merge`, and refuses a layer
whose commits credit an AI, since that call keeps GitHub's message. Never
stack on a PR that can't merge soon (a fork pin, an owner decision, a long
eval). Repairs: `reference/stacking.md`.

**Pausing merges:** while `~/.local/state/orchestrate/<repo name>.paused`
exists (a history rewrite, a broken main), `--merge` refuses; its text says why.

## Gotchas

- **Clean `merge-tree` is not compatibility.** PRs green alone broke main
  three times; only building the combination (the combo) proves it.
- **The PR merge ref lags main**, so `orch-mergecheck` counts landings from
  `LAG_MINUTES` before the run. **A rerun reuses the old merge commit:**
  after main is fixed, affected PRs need a push.
- **Marking ready starts a new run;** green as a draft is not green. **A
  conflicting PR gets no run at all;** `orch-conflicts` lists them.
- **Shared version numbers collide:** parallel PRs bumping one constant all
  pick "next". Assign them in merge order.
- **Waivers:** accept one when the lane can't observe the change; refuse it
  when the change touches what the lane exists to prove.

## Not possible

- Rewriting main while its ruleset is active: the owner deactivates it.

The evidence behind each rule is in
`../orchestrate-sessions/reference/incidents.md`.
