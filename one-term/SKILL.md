---
name: one-term
description: "One behaviour, one term: name each thing, action and behaviour with one term and keep it everywhere, in replies, PR bodies, docs, UI copy, comments and code names. No synonyms, no rewording of a sentence that already exists. A different term only for a different thing, a different context, or a stated reason. Use whenever you write or edit text that a person or an agent reads, and when the owner says 'one term', 'one name per thing' or 'don't paraphrase'."
---

# One behaviour, one term

A reader takes a new term for a new thing. When "the first append" becomes
"the first `melColumns` call" a clause later, the reader stops to check
whether those are two events. Models vary terms for style. Here a varied
term is a bug.

## Happy path

1. **Take the term that exists.** Before you name something, find the term
   already in use: the owner's term in this conversation, the project's
   terms (a docs guide, a glossary, a Terms section), the UI label, the
   identifier in the code. Use it as written. Coin a term only when none
   exists, define it in one sentence where the reader first meets it, and
   use it from then on.
2. **Keep it.** Every later mention of that thing uses the same term. This
   holds for verbs too: if a step "pairs" a device, it never "links" or
   "connects" one. Inflections (append, appended) and a pronoun for the
   thing just named are fine.
3. **Copy a sentence, never reword it.** When the same behaviour is
   described twice (two pages, two platforms, a reply and its PR), copy the
   sentence word for word. A reworded sentence reads as a different
   behaviour.
4. **Change a term only for a reason.** A different term means a different
   thing, or the same thing in a context that has its own term for it: the
   identifier in a code block, the exact label in UI steps. Tie the two once
   ("the first append, the first `melColumns` call") and then use one.
5. **Check before sending.** For each thing the text names, list the terms
   used for it. More than one with no reason from step 4: keep one and
   replace the others.

## Gotchas

- **A description and an identifier for one thing.** "The first call" and
  "the first append" read as two events. Rule: one term per text, tied once
  if both are needed.
- **A short form is a second term.** "Question tool" for "question
  picker" reads as another tool. Rule: the full term every time, or define
  the short form once and switch for good.
- **Each product's own name.** Naming each harness's own tool is fine.
  Rule: the shared behaviour still gets the shared term ("question picker")
  and the same sentence in every harness's section.
- **Restating the owner in your words.** A paraphrase gives their thing a
  second term, which they then map back. Rule: reuse their term even when you
  would pick another. Propose a rename as a question, never in the text.
- **Labels coined mid-task.** "Phase B" or "the cleanup" means nothing to
  someone who wasn't there. Rule: say what the thing is, in the project's
  term.
- **Half a rename.** Renaming in one place leaves two terms in the repo.
  Rule: a rename covers docs, UI strings, comments and specs in the same
  change; keep the old term only where an inbound link or API needs it.
- **A term the owner picked.** Rule: it stays. A reviewer's or a copy pass's
  rename is a proposal for the owner, not an edit.
- **One term for two things.** The reverse fails too: it hides a difference.
  Rule: when two things behave differently, give each its own term and say
  the difference once.

Where the rule came from: [reference/sources.md](reference/sources.md).
