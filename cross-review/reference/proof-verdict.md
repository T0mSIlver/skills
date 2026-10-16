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
