---
name: docs-review
description: "Write, edit or review a project's user docs: README, docs/ pages, CLI, server and plugin READMEs. Checks every claim against the code, gives each fact one page that the others link to, says one behaviour in one sentence wherever it appears, and trims. Use whenever a change touches docs or makes a doc claim stale, and for a docs pass after a release. Triggers: editing README.md or docs/, a renamed flag, label, default or limit, 'refresh the docs', 'review the docs'."
---

# Docs review

Docs fail in three ways: a claim the code no longer backs, the same fact told
twice in two wordings, and text the reader can't act on. This skill catches
all three. For how sentences sound, run `unnarrate` and then `unslop` on
every paragraph you write; this skill doesn't repeat them.

Read the project's own docs guide first (`docs/AGENTS.md`, a docs section in
`AGENTS.md` or `CONTRIBUTING.md`). Its page map, terms and voice win over
this skill.

## Happy path

1. **List what changed.** For a pass after a release, read
   `git log --oneline <previous tag>..origin/main` and the decision records
   (`spec/`, ADRs) changed since. For a code change, search the docs for
   each name, flag, label, default and number the change touches.
2. **Check each claim against the code,** never against another doc, a
   spec or memory. Label: search the UI source for the exact string. Number
   (timeout, size, limit, default): find the constant. Flag: the CLI's help
   text. Version: the release list. Keep the file and line for each claim you
   change; the PR body cites them.
3. **Give each fact one home.** Each page answers one reader question, and
   the fact lives on the page whose question it answers. Elsewhere, a few
   words and a link. When you find a fact on two pages, keep it on its home
   page and cut the other copy to a link.
4. **Say each behaviour in one sentence.** When two products, platforms or
   modes behave the same, write the sentence once and put the differences
   beside it. Where the same behaviour must appear on several pages, copy the
   sentence word for word. A reworded sentence reads as a different
   behaviour.
5. **Trim.** Cut what the reader can't act on: internals, history, why a
   decision was made (that belongs in the decision record). Paragraphs run
   about 3 lines.
6. **Keep inbound links working.** Renaming a heading changes its anchor.
   Search the repo, the apps and the landing page for each renamed anchor.
   Keep an old one that outside pages use with `<a id="old-anchor"></a>`
   above the heading.
7. **Run `unnarrate`, then `unslop`,** on the diff.
8. **Write a short PR body:** each stale claim with the file that proves the
   new one, what moved where, and the word count before and after.

## Gotchas

- **Two wordings drift apart.** A fact restated on a second page doesn't
  get the next fix. Rule: link to its home instead. Repeat only the one
  sentence that names a shared behaviour, verbatim.
- **Terms defined page by page.** Readers meet a term on whichever page they
  land on. Rule: define each term once, on the first page, and link there
  (`one-term` keeps one term per thing). Keep a list order, such as the order
  of supported platforms, the same everywhere.
- **A ✓ with the catch in a footnote.** Readers trust the cell. Rule: put
  the condition in the cell ("CLI only", "Opt-in", "With add-on").
- **Claims wider than the code.** "Works in X" when only X's CLI was
  checked. Rule: name the surfaces checked, and say "untested" for the rest.
- **Claims about other tools age silently.** Rule: version or date each one
  ("CLI 0.160 or later", "menu names from October 2026"), and link that
  tool's docs instead of copying them.
- **Versions in examples.** A pinned `v1.2.3` in a clone or upgrade command
  goes stale every release. Rule: link the latest release, show the tag as
  an example, and update it on every pass.
- **"Since 1.4" notes.** Once every supported release has the feature, the
  note is noise. Rule: drop it.
- **UI labels from memory.** Paraphrased labels send readers hunting. Rule:
  copy the exact string from the source and give the path, such as
  Settings → Notifications → Sound. Defaults and choices come from the code
  too: a setting the docs call opt-in may be on by default.
- **A feature that changed shape.** A switch that became a choice, or a
  "comes back at the end" that now has a mid-way path. Rule: for each
  release change, reread every sentence that describes the old behaviour,
  not only the one the PR touched.
- **Maintainer content in the user path.** Contract tables, CI internals and
  schemas stop readers where they sit. Rule: move them below the user
  content, or to their own page.
- **No proof at the end of setup.** Rule: the getting-started steps end with
  one that shows it works (a test message) and say what to run when it
  doesn't. List every file and service setup writes on the machine.
- **Reviewer rewrites of picked words.** Rule: a label, name or term the
  owner picked stays. A reviewer's rename is a proposal for the owner, not an
  edit.
- **Docs read by agents.** Each always-loaded line costs tokens on every
  turn. Rule: keep the steps in the main file, and move reference that only
  some readers need behind a link.

## Checks before the PR

- Every number, label, flag and path you touched is in the code as written.
- Each fact you touched lives on one page; others link to it.
- Each shared behaviour reads the same sentence everywhere.
- Every anchor you renamed is found nowhere else, or kept with an `id`.
- A fresh reader, such as a model with no repo access given only the
  changed pages, can follow the steps to the end
  ([reference/sources.md](reference/sources.md), "Reader test").

## Not possible

- Checking another tool's UI without running it. Say "checked on <date>
  with <version>" only for what you ran; for the rest, link that tool's docs.
