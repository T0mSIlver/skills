---
name: evidence-bundle
description: "What an agent proves before the owner sees its PR or outward draft, and who decides next. Tests on the pushed head, before/after renders, every claim checked against its source, a fresh Sonnet refuter, cross-review (on the sandbox, from a cloud thread through Remote Control), gathered in one PR comment with a trust level named for who acts: Do (the agent merges), Pick (the owner picks on one card, work goes on with the default) or Yours (the owner, or the agent right after his go). Use when finishing any change or draft that reports to the owner, in a Claude project thread or any session, and before merging without the owner."
---

# Evidence bundle

The owner reads the bundle, not the diff. It runs `blast-radius` (author),
`verify` (second agent) and `cross-review` (other vendor), and adds one
summary, a trust level, and how a cloud thread gets each piece.

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
   matches or what the source says instead. Name each source by repo, ref and
   path: one it can't open comes back "no source", which reads like a gap.
   Anything public also names no private repo of the owner's: no link, no
   `repo #12` reference, branch, file path or artifact built from one.
4. **Fresh refuter.** A Sonnet subagent (never Fable) with the `verify` skill
   gets the repo, PR number, head SHA and a checkout at that SHA, and the
   instruction to find what's wrong. Nothing else: no transcript, no summary
   of why the change is right. In the cloud, tell it to read the PR with the
   GitHub MCP tools or `gh api`, since `gh pr` fails there. Recheck each
   finding yourself before acting on it. Fix what holds and push; a
   second refuter round isn't needed. A finding you can't fix goes to the
   owner as Pick.
5. **Cross-review.** Skip it only where `cross-review` §1 allows, and say so.
   On the sandbox, run it yourself. From a project thread, start one Remote
   Control session per batch (`start_remote_control`, not one per PR; it
   answers a message of the owner's, so it can't start unprompted) in the
   one folder the owner approved for all sandbox sessions,
   `/home/dev/work/T0mSIlver`, and `cd` from there; never ask for another
   folder. Tell it, per PR: check out the head SHA, write a 5–15 line brief to a file
   (task, constraints, claim, how it was verified), run `cross-review --brief
   FILE`, and post the findings as one PR comment; for a merge-by-default
   PR, also `cross-review --proof <n>`. Not run when it was due: a
   "Not verified" line, not a reason to ask.
6. **Post the bundle** as one PR comment, edited on every push, then act on
   its trust level. The thread's reply to the owner is the comment's first
   four lines and a link.

```markdown
<!-- evidence-bundle -->
## Evidence at <short head SHA>

**Claim:** <what is now true, one sentence>
**Trust:** Do, merging | Pick, your call (default: …) | Yours, yours to do. <why this level>
**Confidence:** high | medium | low, resting on <the one fact>
**Not verified:** <each gap and what would close it>

| Claim | Evidence (run link, file:line, image) | Got to |
|---|---|---|

**Refuter** (Sonnet, fresh, at <sha>): VERIFIED | NOT VERIFIED | INCONCLUSIVE. <findings: fixed, or rejected because>
**Cross-review:** <vendor>, N findings, fixed X, rejected Y because … | skipped: <rule> | not run: <why>
**Claims checked:** N of N against their sources <link to the table>
**You decide:** <one question, with the default> (Pick and Yours only)
```

## Trust levels

`owner-charter` "Who acts" sets the level: **Do** (the agent merges, then
one line), **Pick** (one card with a default, work goes on meanwhile) or
**Yours** (the owner, or the agent right after his "go" naming the item).
The repo's AGENTS.md and CONTRIBUTING.md win (the fast-lane repos,
vidtheque and working-set, push to main and are reviewed nightly). Do
merges once every check is green at the head SHA and the bundle is posted;
edit the bundle to "Do, merged" after.

Work the owner didn't ask for goes up as a draft PR labelled `proposal`, with
its bundle and a 30-second demo. It never merges without him. Close it
unanswered after 7 days.

## Gotchas

- **A refuter who read your reasoning agrees with it.** Pass the PR and SHA,
  never the summary. Same for the claims checker: the source, not your notes.
- **"Not verified: none" from a cloud thread is almost always false.** No
  Mac, no device, no sandbox: name each one the change needed.
- **Green as a draft is not green.** Some lanes skip drafts (localvoxtral
  `mac-lanes`); count each check's state on the head SHA.
- **A push makes the bundle stale.** Merge only when its SHA is the head's.
- **Green alone isn't green with main.** Two PRs green on their own heads
  have broken main together. Before merging, check what landed on main
  after the PR's CI run; if it touches the same code, merge main in and push.
  A rerun reuses the old merge ref, so push instead of rerunning.
- **Remote Control turns off the thread's folder access** and shows the
  owner an approval prompt. Ask once a night, never on Sunday, and keep
  working; no answer leaves cross-review as a "Not verified" line,
  never a reason to wait.
- **Haiku misreads long sources.** Give it the page section, not the site;
  a mismatch it reports gets rechecked by you before you change the text.

## Not possible

- Cross-review inside a cloud container: opencode and Codex live on the sandbox.
- Proving a visual change without a render.
