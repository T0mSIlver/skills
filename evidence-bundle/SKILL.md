---
name: evidence-bundle
description: "What an agent proves before the owner sees its PR or outward draft, and who decides next. Tests on the pushed head, before/after renders, every claim checked against its source, a fresh Sonnet refuter, cross-review (on the sandbox, from a cloud thread through Remote Control), gathered in one PR comment with a trust level: L0 the agent merges, L1 the owner says yes, L2 the owner does it. Use when finishing any change or draft that reports to the owner, in a Claude project thread or any session, and before merging without the owner."
---

# Evidence bundle

The owner reads the bundle, not the diff. Spend tokens on proof so the owner
spends a minute deciding. The bundle runs skills that already exist
(`blast-radius` by the author, `verify` by a second agent, `cross-review` by
another vendor) and adds what they don't: one summary, a trust level, and how
a cloud thread gets each piece.

## Happy path

1. **Push first.** Every proof runs on the pushed head SHA. A proof on local
   work or an older head counts for nothing.
2. **Author's proof.** Write the PR's Blast radius section (`blast-radius`).
   Take each claim in the PR body to "ran it" where it can run: a bug fix's
   test fails on the base and passes on the head; anything that renders gets
   before and after at the same viewport, light and dark; motion gets a
   recording. Open every image and say what it shows.
3. **Claims check.** For prose, posts and outward items, list every number,
   name, date, link and quote with the source you took it from. A Haiku
   subagent gets only that list and opens each source; it returns, per claim,
   matches or what the source says instead.
4. **Fresh refuter.** A Sonnet subagent with the `verify` skill gets the repo,
   PR number and head SHA, and the instruction to find what's wrong. Nothing
   else: no transcript, no summary of why the change is right. Fix what it
   proves, push, rerun it on the new head. One fix round; a second NOT
   VERIFIED goes to the owner as L2 with the finding.
5. **Cross-review.** Skip it only where `cross-review` §1 allows, and say so.
   From a cloud thread, start one Remote Control session per batch (not per
   PR) on the sandbox and tell it: check out each head SHA, run
   `cross-review --brief`, post the findings on the PR. Not run when it was
   due: the PR can't be L0.
6. **Post the bundle** as one PR comment, edited on every push, then act on
   its trust level. The thread's reply to the owner is the comment's first
   four lines and a link.

```markdown
<!-- evidence-bundle -->
## Evidence at <short head SHA>

**Claim:** <what is now true, one sentence>
**Trust:** L0, merged | L1, needs your yes | L2, yours to do. <why this level>
**Confidence:** high | medium | low, resting on <the one fact>
**Not verified:** <each gap and what would close it>

| Claim | Evidence (run link, file:line, image) | Got to |
|---|---|---|

**Refuter** (Sonnet, fresh, at <sha>): VERIFIED | NOT VERIFIED | INCONCLUSIVE. <findings: fixed, or rejected because>
**Cross-review:** <vendor>, N findings, fixed X, rejected Y because … | skipped: <rule> | not run: <why>
**Claims checked:** N of N against their sources <link to the table>
**You decide:** <one question, with the default> (L1 and L2 only)
```

## Trust levels

The first that applies wins. A repo's AGENTS.md overrides it (the fast-lane
repos, vidtheque and working-set, push to main and are reviewed nightly).

- **L2, the owner does it.** Anything sent or published outside his repos
  (send packet, `owner-charter` "Never"), opinions or a thesis in his voice,
  money, anything irreversible.
- **L1, the owner says yes on one card.** `.github/`, `deploy/`, auth,
  migrations, secrets; a push that deploys to production (website `main`);
  what `owner-charter` puts on a card (feature, UX, visible copy); a refuter
  INCONCLUSIVE; cross-review due and not run.
- **L0, the agent merges and says so in one line.** Every check green at
  the head, refuter VERIFIED at the head, cross-review clean or skipped by
  its rule, bundle SHA equal to the head SHA.

Work the owner didn't ask for goes up as a draft PR labelled `proposal`, with
its bundle and a 30-second demo. It never merges on L0. Close it unanswered
after 7 days.

## Gotchas

- **A refuter who read your reasoning agrees with it.** Pass the PR and SHA,
  never the summary. Same for the claims checker: the source, not your notes.
- **"Not verified: none" from a cloud thread is almost always false.** No
  Mac, no device, no sandbox: name each one the change needed.
- **Green as a draft is not green.** Some lanes skip drafts (localvoxtral
  `mac-lanes`); count each check's state on the head SHA.
- **A push makes the bundle stale.** Merge only when its SHA is the head's.
- **Remote Control turns off the thread's folder access** and shows the
  owner an approval prompt. Ask once per night and keep working; no answer
  means the PR stays L1, never a reason to wait.
- **Haiku misreads long sources.** Give it the page section, not the site;
  a mismatch it reports gets rechecked by you before you change the text.

## Not possible

- Cross-review inside a cloud container: opencode and Codex live on the sandbox.
- Proving a visual change without a render.
