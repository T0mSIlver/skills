---
name: correct
description: "Turn a repeated mistake into a check that fails on it. When the owner makes the same correction twice, or a reviewer or verifier finds the same class of problem twice, add the highest check that catches it (a type, then a lint whose message names the fix, then a test, then a verifier rule, then a doc), prove it fails on the past mistake, and keep the repo's AGENTS.md rule → check table. Use whenever the owner corrects you, when a finding repeats, and for 'never again' or 'make this impossible'."
---

# Correct

Assume the next contributor is an agent that sees only the files it opened,
copies the nearest example, and takes the shortest path that compiles. A
rule it has to remember fails; a check that fails its build doesn't.

## On every correction

1. **Fix the instance.**
2. **Look it up** in the repo's rule table (AGENTS.md, "Rules and their
   checks"). Then search for earlier cases: `git log -S`/`--grep`, review
   threads (`gh api repos/<o>/<r>/pulls/comments`), past `cross-review` and
   `verify` findings.
3. **First time:** add a row with `Check: none yet` and the PR or message
   that showed it. The row is how the second time gets noticed.
4. **Second time** (a row already there, or an earlier case found): build
   the check now, in this change or the next PR.

## Pick the highest check that catches it

1. **Type:** make the bad state impossible to write. When the mistake comes
   from two ways of doing one thing, delete one; then there is nothing to
   get wrong.
2. **Lint or CI check whose message names the fix:** "use `formatTime()`
   from `shared/time.ts`, not `toLocaleTimeString`", not "invalid time
   format". If the pattern is already common, fail only on lines a change
   adds.
3. **Test** of the behaviour, through the `test-audit` gate.
4. **Verifier rule:** for what only a render or a run shows (off-centre,
   clipped, wrong in one locale), a rule in the repo's `verify-<app>` skill
   that says what to measure and the tolerance.
5. **Doc:** an AGENTS.md line, only for a judgment call no check can make.
   Nothing fails when an agent skips it.

## Prove it

Run the check on the real past mistake: check out the bad commit in a
scratch worktree, or reapply its diff, and paste the failing output. Then
run it on the fix and show it pass. The same command runs locally and in
CI.

## The table

```markdown
## Rules and their checks

| Rule | Check | Seen in |
|---|---|---|
| App icon centred against its peers | verify-android rule "icon centre" | #41, #57 |
| UI strings carry no AI tells | `pnpm lint:copy` | #63 |
| A Settings subtitle only when the title can't stand alone | none yet | #70 |
```

A row whose check is "none yet" and that is seen again is a repeat: build
the check in the same change. Drop a row once its mistake can't happen.

## Gotchas

- **A message that names no fix** gets the check suppressed or worked
  around by the next agent.
- **Proving on an example you made up** misses what the real mistake looked
  like (a regex that catches your example and not the past diff).
- **A doc-level fix when a check was possible** is how the same correction
  comes a third time.
- **Exceptions** go on the offending line, with the reason.
- **A broad exemption** (a whole directory) turns the check off. Fail only
  on new lines instead.
- **One check per commit,** naming the correction it encodes, so a revert
  is clean.
