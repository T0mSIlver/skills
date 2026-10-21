---
name: one-term
description: "One behaviour, one term: give each thing one term and keep it, and copy a sentence that must repeat word for word instead of rewording it. Change a term only for a different thing, a different context or a stated reason. Use when writing or editing docs, UI copy, a PR body, a comment or a reply that refers to something the owner, the code or the docs already have a term for, and when the owner says 'one term', 'one behavior = one term' or 'don't reword'."
---

# One behaviour, one term

A thing here is anything text refers to: an object, an action, a behaviour.
A reader takes a new term for a new thing, so a varied term is a bug.

## Happy path

1. **Take the term that exists.** Before you write a term, find the one
   already in use: the owner's term in this conversation, the project's
   terms (a docs guide, a glossary, a Terms section), the UI label, the
   identifier in the code. Use it as written. Coin a term only when none
   exists, define it in one sentence where the reader first meets it, and
   use it from then on.
2. **Keep it.** Every later mention of that thing uses the same term, verbs
   included: if a step "pairs" a device, no later step "links" or
   "connects" one.
3. **When a sentence must repeat, copy it.** One behaviour described in two
   places (two platforms on one page, a doc and the CLI's help) gets the
   same sentence, word for word. A reworded sentence reads as a different
   behaviour.
4. **Change a term only for a stated reason.** A different term means a
   different thing, or the same thing in a context that has its own term
   for it: the identifier in a code block, the UI label in steps. Tie the
   two once ("the first append, the first `melColumns` call") and then use
   one term per thing.
5. **Check before sending.** For each thing the text refers to, list the
   terms used for it. More than one, without a stated reason from step 4:
   keep one.

## Gotchas

- **A short form is a second term.** "Question tool" for "question
  picker" reads as another tool. Rule: the full term every time, or define
  the short form once and keep the short form.
- **Each product's own term.** A harness's own tool keeps its own term
  ("AskUserQuestion"). Rule: the behaviour harnesses share still gets the
  shared term ("question picker") and the same sentence in each harness's
  section.
- **The owner's term reworded.** Rewording what the owner said gives their
  thing a second term, which they then map back. Rule: reuse their term
  even when you would pick another; propose a change as a question, never
  in the text.
- **A term changed in one place.** The repo now has two terms for one
  thing. Rule: change a term in docs, UI strings, comments and specs in
  the same change; keep the old term only where an inbound link or an API
  needs it.
- **A term the owner picked.** Rule: it stays. A reviewer's or a copy
  pass's change to it is a proposal for the owner, not an edit.
- **One term for two things.** It hides a difference. Rule: when two
  things behave differently, give each its own term and state the
  difference once.

Where the rule came from: [reference/sources.md](reference/sources.md).
