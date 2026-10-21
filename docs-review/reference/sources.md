# Sources

Where each rule in `SKILL.md` comes from. The rules that come from review
threads are the ones reviewers corrected more than once.

## Review history (T0mSIlver/starbridge docs PRs, 2026)

| Rule | PRs where reviewers raised it |
|---|---|
| One behaviour, one sentence | #1047, #1053, #1054, #1271, #1273 |
| Check each claim against the code, cite the file | #564, #761, #1047, #1053, #1054, #1136, #1271 |
| One home per fact, others link | #1271, #1273 |
| One term per thing, defined once | #1047, #1053, #1271 |
| Name the exact condition a behaviour holds in | #761, #1047, #1136, #1271 |
| Don't overstate support | #564, #1047 |
| Cut mechanics the reader can't act on | #1047, #1273 |
| Keep anchors working | #1047, #1053, #1271, #1273 |
| Keep internal context out of public text | #502 |

Examples of each, from that project: [examples.md](examples.md).

Process lessons from the same PRs:

- The PR body lists what was checked, what was left out and why, and the
  word count before and after, so a reviewer can audit the scope.
- Rejected review findings get a reason in the PR body.
- A docs guide that describes the site (which pages it serves, which pages
  link an anchor) is a claim too; check it like the others.

## Blind reader reviews

Four reviewers with personas (first-time user, self-hoster, open-model user,
fleet operator) read only the public docs, twice, before and after a rewrite.
What they flagged in both rounds:

- No step at the end of setup that proves it works (4 of 4, both rounds).
- Maintainer tables in the user path, where they stopped reading (3 of 4).
- Side effects of setup not listed (3 of 4).
- A ✓ qualified on another page (3 of 4, then 2 of 4).
- Security claims without the limits beside them (4 of 4, then 2 of 4).

Readers with no repo access can't check facts, so they find missing proof,
scattered facts and the wrong reader, not stale claims. Use them for that,
and the code for facts.

## Reader test

Anthropic's `doc-coauthoring` skill ends with a reader test: give the draft
to a fresh model with no context and check that it works for the reader.
https://github.com/anthropics/skills/blob/main/skills/doc-coauthoring/SKILL.md

## Other guides

- Diátaxis (https://diataxis.fr/): tutorials, how-to guides, reference and
  explanation are separate modes; don't explain inside a how-to or a
  reference entry, link instead. Reference "mirrors the structure of the
  product".
- Matt Pocock, `writing-for-agents`
  (https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-for-agents/SKILL.md):
  synonyms for one case are duplication; keep one concept's rules under one
  heading; always-loaded lines cost tokens every turn, so move reference
  behind a pointer.
- Google developer documentation style guide
  (https://developers.google.com/style/highlights): second person, active
  voice, sentence-case headings, the condition before the instruction, and
  consistency within a document over any single rule.
- `unslop` (vendored from cursor/plugins): one name per thing, no synonym
  cycling. `one-term` holds the full rule.

## Other projects on the same box

- vidtheque: one document owns each list ("ROADMAP is the only list of open
  work"); cite the file, not the memory.
- localvoxtral: the README is a landing page, user docs live in `docs/`;
  code and scripts cite docs by section name, so a renamed section breaks
  them; a claim needs output that proves it.
- herdr: published doc versions are frozen; a fix to one also goes to the
  draft.
