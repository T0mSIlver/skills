---
name: verify
description: "The verifier: a second agent, not the author, checks a PR before merge. Reads the diff, issue, intent card, spec and the PR's blast radius; runs or reads the evidence; looks at every screenshot and video itself; compares against peers on the same screen, and against main for a bug fix; does a refuter pass; and returns VERIFIED, NOT VERIFIED or INCONCLUSIVE with its scope, recorded for the ramp-up tally. Also how to write a repo's verify-<app> skill. Use when asked to verify a PR or change, before merge-queue merges one, and when a repo has no scripted way to drive its app."
---

# Verify

You didn't write the change, and you don't read the author's transcript:
the PR is what ships, so the PR is what you judge. You report; the author
fixes.

## Happy path

1. **Read the inputs.** `gh pr view <n>` and `gh pr diff <n>`, the issue,
   the intent card's answer or the spec it cites, and the PR's Blast radius
   section. No blast radius: stop at NOT VERIFIED, since the author owes it.
2. **Check the blast radius.** List every surface the diff reaches. Each one
   the section misses is a finding, and you prove it like the rest.
3. **Check the intent.** Anything the card or spec didn't ask for (a page,
   setting, option, abstraction) is a finding. A deviation from the owner's
   answer goes to the owner on a card (`intent-card`), never into a merge.
4. **Gather the evidence, risk by risk.** Read what CI already proved: the
   screenshot diff and the e2e run, on a run whose head SHA is the PR's
   head. Drive the real app only for risks the suite doesn't cover, through
   the repo's `verify-<app>` skill. Exercise each feature the way its users
   do, with fake users when it involves more than one person or device.
5. **Look at every image and video** at full size before judging: open each
   file, and pull frames from a video at its key moments. Write what each
   shows and whether it looks right against the charter's "looks off" list.
6. **Compare with peers on the same screen:** the icon against the icons
   beside it at the same size, the row against the rows above and below, the
   same screen on the other platforms. Where the eye is unsure, measure
   (bounding-box centres, text width against its box).
7. **Bug fix: baseline on main.** Reproduce the bug on main with the same
   steps, then show it gone on the PR head.
8. **Edge cases.** Those in the issue, plus the ones the risks call for:
   empty and very long content, another locale, dark theme, small screen
   and large font, offline, first run and upgrade from the last release.
9. **Refuter pass.** Argue against your own verdict before posting it.
   VERIFIED: what would make this evidence not cover the claim? A stale
   build, an artifact from an older head, a test that passes on main too,
   one platform standing in for another. NOT VERIFIED: does the finding
   reproduce, on a concrete path, and is it the app and not the harness?
10. **Post the verdict** as one PR comment (`gh pr comment`):

```markdown
## Verification: VERIFIED | NOT VERIFIED | INCONCLUSIVE

**Scope:** <platforms, features and risks this covers, at head <sha>>
**Not covered:** <what, and why>

| Risk | Evidence | Got to | Looks right? |
|---|---|---|---|
| <from the blast radius> | <run link, image, file:line> | ran it | yes: <what it shows> |

**Findings:** <each with file:line or image, and how to reproduce>
Tally: kind=<kind> verdict=<verdict> head=<sha>
```

One `Tally:` line per kind of risk the PR carries, using the blast radius's
kinds. `merge-queue` adds the owner's verdict beside it during the ramp-up
and counts the matches.

## Verdicts

- **VERIFIED:** every risk in scope has evidence that would have caught it,
  and you looked at it.
- **NOT VERIFIED:** a finding reproduces, or the author's proof is missing.
- **INCONCLUSIVE:** the evidence couldn't be produced (no device, flaky
  run). Say what would settle it. Never round it up.

## Writing a repo's verify-<app> skill

Each repo keeps `.claude/skills/verify-<app>/` saying how to launch, check,
drive and prove its app, with one feature file per user-facing feature.
[reference/verify-app-skill.md](reference/verify-app-skill.md) has the shape.
Run it end to end once before committing it: a verify skill that never ran
is a draft.

## Gotchas

- **A thumbnail hides a 4 px offset.** Crop to the element and its peers.
- **The wrong build looks right.** Check the version or build id on screen or
  in the doctor output before judging what it shows.
- **Emulators and simulators** differ from devices in icon masks, fonts and
  notch insets. Name what you ran on in the scope.
- **Findings go to the PR,** not to the owner. A card only for a deviation
  from intent, or for UX proof during the ramp-up.
- **A finding with no concrete path** ("what if…") is dismissed, not
  reported. Trace the caller first.

## Not possible

- Proving a visual change by reading code: it needs a render.
- Hardware the box doesn't have: INCONCLUSIVE, with that gap in the scope.
