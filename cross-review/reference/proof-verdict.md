# Proof verdict

`cross-review --proof PR` adds `assets/proof.md` to the reviewer's prompt and
`assets/schema-proof.json` as Codex's output schema. HEAD must be the PR's
pushed head, or the run stops before any review.

The script, not the reviewer, has the last word on two things:

- **Verdict.** An open P0 or P1 finding turns PROOF SUFFICIENT into PROOF
  INSUFFICIENT and adds the finding to the reasons.
- **Class.** It becomes `sign-off` when the change touches `.github/` or
  `deploy/`, when the PR edits the "What merges without the owner" section of
  CONTRIBUTING.md, or when the base branch has no such section. The reviewer
  sees that section as it is on the base branch, never the PR's copy.

The comment's lines are `- Head: <sha>`, `- Reviewer: <vendor> (<model>)`,
`- Verdict: …`, `- Class: …`, then `Reasons:`. Only a comment by the
authenticated `gh` user is edited. The comment is not written if the PR moved
during the review. Nothing here merges anything: `orch-automerge-ready`
(merge-queue) reads the comment.

## Where the grading rules come from

Researched 2026-10-17. Wording is paraphrased; every source below is MIT-licensed.

- **Shipped entry point, tests never replace it; media proves only what it
  shows; upgrade run for stored data; a regression test fails on base; paperwork
  is not a gap; truncated input is not a pass.** openclaw/clawsweeper
  `prompts/review-item-pr.md` (section 6 "Proof") and the "one gap, one place"
  rule; openclaw/agent-skills `skills/autoreview/SKILL.md` ("truncation or
  unfinished assessment means incomplete, never clean").
- **The one fact a change is safe because of.** cursor/plugins
  `pstack/skills/blast-radius/SKILL.md` (pstack, Lauren Tan's Cursor plugin;
  the other "pstack" repos on GitHub are ports of it). The how-sure ladder in
  item 2 already came from here. The refute pass is this repo's `verify`
  skill, step 9, moved into the proof prompt.
- **Before and after for an existing screen, a recording for motion.**
  pingdotgg/t3code `.github/pull_request_template.md` and AGENTS.md;
  openclaw `proof-video` skill (same viewport and crop before and after).
- **A claim the diff does not support is a gap.** clawsweeper "Body claims".
- **Short comment.** One sentence per reason, each gap once (clawsweeper).

Rejected: committing proof files to the repo (CodexBar's `.github/pr-proof/`;
t3code forbids it, and evidence on the PR is enough); a graded S to F rating or
a third verdict (the comment gates auto-merge, so it stays binary); attaching
images for the reviewer to see (openclaw autoreview does it for Codex only, with
size limits; the CI screenshot job and the verifier already look); feeding the
previous verdict back in on a rerun (it anchors the reviewer on an old
SUFFICIENT); CodexBar has no review bot, only live-QA skills.
