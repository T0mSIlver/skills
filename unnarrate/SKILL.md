---
name: unnarrate
description: Remove self-narrating meta-commentary — text that describes the artifact it lives in, restates what the reader already sees, or narrates the process that produced it — from UI copy, docs, code comments, commit messages, and PR descriptions. Apply whenever writing or reviewing those surfaces, and before unslop when editing prose. Triggers: tooltips restating labels, "This section describes...", comments restating the next line, "progress is shown while it runs", PR bullets restating the diff.
---

# Unnarrate

Companion to `unslop`. Unslop fixes how AI prose sounds; this deletes text
that should not exist at all: **meta-commentary** — writing that narrates the
artifact to its own audience. A progress bar already announces progress;
"progress is shown while it runs" beside it is a second, redundant signifier.
Agents produce this constantly because they narrate their chain of thought
into every surface they touch.

## The deletion test

Delete any sentence, label, or comment whose only content is:

1. a description of the artifact it lives in ("This section describes..."),
2. something the reader can already see (a tooltip restating the label, a
   comment restating the next line), or
3. the process that produced it (`// As requested, extracted into a helper`).

Two checks decide close calls:

- **Delete it mentally.** If the reader loses nothing, it was a no-op — text
  that appears to do something but changes nothing.
- **Portability.** If the line could appear unchanged in another project,
  another PR, or above different code, it says nothing about this one. Cut it.

## What to cut, by surface

### UI copy

- Copy describing behavior the interface already performs: "Progress is shown
  while installing", "A spinner appears while loading", "The list updates
  automatically". The widget is the signifier; don't add a verbal one.
- "Loading..." text beside a visible spinner; "File uploaded successfully" →
  "File uploaded".
- Tooltips and help text restating the label: field "City of birth", tip
  "Enter the city of your birth".
- Positional narration: "Click the button below to submit", "Select an option
  from the dropdown".
- Onboarding/coach-mark copy that inventories every control instead of
  pointing at the one non-obvious action.
- Accessibility duplicates: `aria-label="Submit button"` on a `<button>`,
  `alt="Image of a chart"` (screen readers already announce the role).

### Docs and READMEs

- "This document describes...", "In this guide, we will...", "Welcome to the
  documentation for X". Start with the content.
- Overview sections that only announce the sections that follow; trailing "In
  summary" paragraphs restating the page.
- Docstrings restating the signature (`get_user(id)` — "Gets the user by
  id"); `<summary>Gets or sets the X</summary>`. PEP 257 bans exactly this.
- "The following example shows how to..." above an example; prose restating
  the adjacent code block.
- Feature bullets and section intros that would be true of any project.

### Code comments

- Restating the next line: `// Import React`, `// Return the value`,
  `// Loop over items`.
- Section banners: `// ===== HELPERS =====`, `// --- Step 3: Validate ---`.
- Plan and phase narration: `// Phase 2: refactor`, `// Using the newly
  created Foo model`.
- Changelog narration: `// Changed from useState to useReducer`, `// Removed
  the old handler`. Git history holds this.
- Comments addressed to the reviewer instead of the future reader:
  `// Note: I kept this behavior intact`.

### Commits and PRs

- Bullet lists restating the diff file-by-file; "This PR adds..." followed by
  the title verbatim.
- Template sections filled with restatement; "Test plan: ran the tests" with
  no specifics.
- Effort narration: "Comprehensive refactor", "Carefully preserved backward
  compatibility". State facts a reviewer can check instead.

## Keep — not everything that narrates is a no-op

- **Live narration is a signifier; static narration is the tell.** An agent
  streaming "Installing dependencies…" as it works is real feedback. Copy
  *describing* that feedback exists is the anti-pattern.
- **"Why" comments stay:** rationale, invariants, warnings about non-obvious
  behavior, links to issues and incidents. The rule deletes restatement, not
  comments — match the surrounding code's comment density.
- **Instructions carrying information the surface can't show stay:** formats
  ("YYYY-MM-DD"), constraints ("8+ characters"), side effects ("this emails
  the team"), irreversibility warnings.
- **Real alt text stays.** Delete the "Image of..." prefix, keep the
  description of what the image shows.
- **TODOs with a tracking link stay;** bare `// TODO: improve this` goes.

## Applying it

1. Sweep the changed surfaces for the patterns above. Delete, don't rewrite —
   most hits need no replacement.
2. When deletion leaves a real gap, fix the artifact (clearer label,
   self-explanatory control), not the narration.
3. Then run unslop on what survives.

`reference/terminology.md` names the phenomenon per community (metadiscourse,
happy talk, obvious comments, no-ops) with sources, for citing or extending
the checklist.
