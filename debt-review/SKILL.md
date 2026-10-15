---
name: debt-review
description: "The weekly debt review of one repo: read the week's merged PRs, find the debt they added or extended (a second way of doing one thing, a feature bolted on instead of designed in, dead code, workarounds, hand-synced lists), and propose for each a redesign from first principles, one owner card each. Use when a scheduled routine or the owner asks for the weekly debt review, 'what debt did we add this week', or a redesign pass. The caller schedules it."
---

# Debt review

The week's PRs each passed review alone; debt shows across them. Find it
while it is a week old and its authors' context is still in the PRs.

## Happy path

1. **List the week's merges:**

   ```bash
   gh pr list --state merged --limit 200 \
     --search "merged:>=$(date -u -d '7 days ago' +%F)" \
     --json number,title,mergedAt,files
   ```

   Skip pure dependency and vendor bumps. Read each remaining diff and its
   PR body.
2. **Find the debt,** in the week's changes and in the old code they
   extended:
   - **Two ways to do one thing:** a new helper beside an old one, a second
     config path, one behaviour built differently in two clients.
   - **Bolted on:** a flag, special case or branch where the model should
     have changed. Tells: the same workaround in unrelated places, edge
     cases that each need their own branch, casts and always-set optional
     fields, callers that must know an abstraction's internals.
   - **Dead code:** exports, flags, routes, strings and settings nothing
     reaches; production code only tests use. Use the repo's own tool (knip,
     detekt, `go vet`) when it has one, else search for references.
   - **Workarounds:** retries or sleeps over a race, `TODO`/`hack`/
     `workaround` comments, copied constants.
   - **Hand-synced lists, split ownership, pass-through layers**
     ([design red flags](../intent-card/reference/design-red-flags.md)).
3. **Confirm each one.** Cite `file:line` on main. Read the PR and issue
   for a reason; a deliberate trade-off with a live reason is not debt.
4. **Redesign from first principles.** What would you build if every
   requirement now in this code had been there from the start? The answer
   should be no bigger than today's code: say what it deletes. Two shapes
   when the structure is in question, as `intent-card` makes them.
5. **Sort the result:**
   - Dead code with no reference, and a second way whose callers move in one
     small PR: no card. Open the PR; say so in the report.
   - A redesign, or removing anything a user can reach: one card each,
     through `intent-card`, at most five, ranked by what leaving it costs
     (bugs it already caused, code it makes every change touch). The rest go
     in one issue.
6. **Report:** each finding with its evidence, what you did (card id, PR,
   or issue), and what you checked and cleared.

## Gotchas

- **A third abstraction over two ways** is more debt. The fix for two ways
  is deleting one.
- **A redesign proposed from the diff alone** misses callers. Read every
  caller of what it would change before posting.
- **Check open cards and issues** first; last week's unanswered card is not
  posted again.
- **Style is not debt.** Naming and formatting go to the author's lint, not
  to the owner.
- **`merged:>=` takes a UTC date;** a run at 00:30 local can miss a day.
  On macOS, `date -u -v-7d +%F` replaces `date -d`.
