# Why the evidence bundle exists

- **The ask (Tom, 21 Oct 2026, project chat):** spend more agent tokens on
  verification so he spends less time reviewing; agents should prove their
  work, and he should trust and use more of his weekly limit.
- **What already existed:** `blast-radius` (author's proof), `verify` (second
  agent), `cross-review` and its `--proof` verdict (other vendor),
  `merge-queue` (merge gate). They were written for desktop sessions on the
  sandbox. A claude.ai project thread has no sandbox CLIs and no Starbridge
  card loop, so it either skipped proof or handed Tom the diff.
- **Fresh refuter with no transcript:** `verify` "you don't read the author's
  transcript"; the anchoring note in `cross-review/reference/proof-verdict.md`
  (feeding a previous verdict back in anchors the reviewer).
- **Trust levels:** `owner-charter` (what goes on a card, "Never"), Tom's
  merge rule in project memory (agents merge his own repos once CI is green
  and reviewed, 20 Oct 2026), the send packet in the owner's private CLAUDE.md,
  website AGENTS.md (main deploys production).
- **`proposal` drafts:** Tom asked for agents to build things he isn't sure
  he needs yet; `owner-charter` forbids merging unrequested features. A draft
  PR with a demo satisfies both; the 7-day close keeps the list short.
- **Pilot:** T0mSIlver/website PR #26, 21 Oct 2026 (bundle comment on the PR).
