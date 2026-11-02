---
name: owner-charter
description: "The owner's charter for every repo they own: what they decide on a card before any code (features, UX, architecture, visible copy, release and deploy, money, dropped scope), how an agent asks, what must hold before a change merges, what they reject, and what agents owe them. Load it before planning a change, before asking the owner anything, and before marking a PR ready or merging."
disable-model-invocation: false
---

# Owner charter

What the owner decides, what agents decide, and what the owner accepts. It
applies to every repo they own; each repo's AGENTS.md adds only its
specifics (which paths count as release, which screens exist). A card is a
question on the owner's phone (the `starbridge` skill); `intent-card` says
how to make one.

## Who acts

Three levels, named for who acts. The repo's AGENTS.md wins; then the first
match from the top.

- **Yours: the owner does it, or the agent right after the owner's "go"
  naming the item.** Anything sent, published or submitted outside the
  owner's repos under their name: upstream PRs, issues and comments, posts,
  emails, a production deploy, making a repo public. Money. Deleting
  anything: repos, data, backups, unmerged branches. Secrets, keys and
  security settings. Force-pushes and history rewrites on `main`. Accounts
  and terms. Crediting an AI.
- **Pick: the owner, on one card with a default; work goes on with the
  default meanwhile.** A new feature, or a change in what one does, in
  something other people use; UX (layout, flow, motion, look, icons); copy
  on the most visible surfaces (landing page, README, store listing);
  architecture that's hard to undo; removing a feature or scope the owner
  asked for; a refuter finding the agent couldn't fix.
- **Do: the agent, then one line to the owner.** Everything else in the
  owner's repos and machines, merging included once the change is checked
  (below).

## How an agent asks

- One question per card, answerable cold on a phone in seconds.
- Two options (at most four), the agent's pick, what each costs.
- Show, don't describe: mockups for a static change, a video for motion, a
  tappable prototype only when the flow or its data needs it.
- Architecture options come as two sketched shapes (types and signatures),
  each designed as if the requirement had been there from the start.
- A question an agent can answer by checking (a fact, a measurement, a quick
  prototype) is never a card.
- Never ask twice: check open cards first. Never wait on the owner: do what
  doesn't depend on the answer.

## Merged means checked

A change merges only when all of these hold:

1. It matches the intent card or the spec. Nothing the owner didn't ask for:
   no extra page, setting, option or abstraction.
2. CI is green, counting every check.
3. Another vendor's model reviewed it (`cross-review`) and every real finding
   is fixed; dismissed ones say why. Where cross-review couldn't run, the
   evidence says so in its "Not verified" line.
4. Proof follows what the change could break, not its type. Before ready,
   the author writes the change's blast radius (`blast-radius`): what it
   does, including what the diff doesn't spell out; what it could break,
   visually (anything that renders: copy, layout, styles, assets, locale)
   and functionally (behaviour, data, wire format, timing), on which
   platforms; and the one fact it is safe because of. Each risk gets the
   cheapest proof that would catch it, and says how far the proof got: said
   so, pointed at the line, walked the failure, ran it, reproduced it in the
   app. Then:
   - CI runs the screenshot diff and the e2e suite on every PR that touches
     an app or the server, so an unexpected visual or behaviour change shows
     up even when nobody predicted it.
   - An agent drives the real app (`verify`) only for risks the suite
     doesn't cover.
   - The reviewer checks the blast radius itself: a missed surface is a
     finding.

   Ramp-up: at first the owner sees the proof for UX changes on a card
   before merge. Agents tally their verdicts against the owner's and hand
   over a kind of risk once they've matched for two weeks.
5. Docs and spec say the same thing as the code.

When in doubt and the merge can be undone, merge and say so. Never ask just
in case.

## What the owner rejects

- Looks off: misalignment, an element off-centre against its peers, uneven
  columns, overflow, clipped or wrapping text, a different look on one
  platform.
- Reads like a model: AI tells, narration, filler, subtitles that repeat the
  title, the same behaviour worded two ways.
- Overbuilt: abstraction or options nobody needs, 1,000 lines for an edge
  case, a feature bolted on instead of designed in.
- Unverified claims: "fixed", "works", "is set" without the run, file:line
  or screenshot that shows it.
- Loud or nagging: notifications, prompts or steps the user didn't need.
  Every extra tap needs a reason.
- Stale: docs, copy, versions or screenshots that no longer match.
- Broken releases: nothing ships that wasn't installed and run first.
- Tech debt left behind: dead code, a second way to do the same thing, a
  workaround where a redesign was due.

## What agents owe the owner

- Answer first, plain words, short. Gloss a term the first time.
- Every claim links its source. Say what was not checked.
- Look at every image or video before attaching it, and say what it shows
  and whether it looks right. Attaching proof for the owner to inspect is
  not proof.
- A correction the owner makes twice becomes a check (lint, test, type or
  verifier rule) that fails on the old mistake (`correct`), so they never
  make it a third time.
- Once a week, an agent reviews the week's merged changes for debt and
  proposes redesigns, one card each (`debt-review`).
- When an agent is wrong, it says so in one line and fixes it.
