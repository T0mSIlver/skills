# Terminology and evidence

What the phenomenon is called, per community, with sources. Researched
2026-08-21 (web sweep + AI Engineer 2026 talk corpus). No single established
name covers all four surfaces; the skill's checklist is a composite of the
named patterns below.

## Umbrella names

- **Metadiscourse** (Ken Hyland, applied linguistics): "self-reflective
  linguistic material referring to the evolving text and to the writer and
  imagined reader of that text" — the academically precise term for text
  about the text. Linguists treat moderate metadiscourse as good; the
  anti-pattern is excess. https://academic.oup.com/applij/article/25/2/156/143310
- **Signposting**: the subtype where text announces its own structure ("as
  will be discussed below") — direct ancestor of "This section describes...".
  https://explorationsofstyle.com/2011/09/01/signposting-and-metadiscourse/
- **No-ops** (Matt Pocock; independently Philipp Schmid, Google DeepMind):
  "things inside the skill that appear to do something but don't actually
  influence the agent's behavior", checked with a **deletion test** — "what
  would happen if you just deleted that paragraph?". Coined for agent skill
  files but generalizes to any surface.
  https://youtu.be/UNzCG3lw6O0?t=1102 · https://youtu.be/0vphxNt4wyk?t=673
- **Narrative comment / meta-comment** (aislop linter): the closest existing
  term of art for the agent-specific version — "narrative comments above
  self-explanatory code", "comments about implementation phases, agent
  behavior, or generated-code process instead of the code itself".
  https://github.com/scanaislop/aislop/blob/main/docs/rules.md
- "Narrating the interface" (the UI-copy form) appears to be unclaimed — no
  compact established label exists for that surface specifically.

## Per community

### Writing and technical writing

- **Throat-clearing**, **lazy emphasis** ("stage directions" that tell rather
  than show), **trailing summary** — Tom Yandell's 11-pattern taxonomy of the
  LLM voice. https://tomyandell.dev/blog/llm-voice
- **Don't belabor the obvious** — Kernighan & Pike, *The Practice of
  Programming*.
- **WP:SELFREF** — Wikipedia's Manual of Style bans "This article
  discusses...". A hard, citable precedent with a shortcut name.
  https://en.wikipedia.org/wiki/Wikipedia:Manual_of_Style/Self-references_to_avoid
- **PEP 257** — a docstring "should NOT be a 'signature' reiterating the
  function/method parameters (which can be obtained by introspection)".
  https://peps.python.org/pep-0257/

### UX and HCI

- **"Happy talk must die" / "Instructions must die"** — Steve Krug, *Don't
  Make Me Think*: eliminate instructions by making the thing self-evident;
  "get rid of half of the words on each page, then half of what's left".
- **Info tips that restate the interface** — Nielsen Norman Group: "Info tips
  also waste time when they restate what's already perfectly clear in the
  interface" (their example: tip "Enter the city of your birth" on a field
  labelled exactly that). https://www.nngroup.com/articles/info-tips-bad/
  Coach-mark critique: https://www.nngroup.com/articles/mobile-instructional-overlay/
- **Redundant signifier** framing — Don Norman: the anti-pattern is adding a
  verbal signifier for an affordance that already has a visual one. A
  progress bar is the signifier; copy describing it is a second, redundant
  one. https://jnd.org/signifiers-not-affordances/
- Accessibility instance: `alt="Image of..."` and `aria-label="Submit
  button"` on a `<button>` — mechanically checkable, well documented.
  https://blog.pope.tech/2022/07/12/what-you-need-to-know-about-aria-and-how-to-fix-common-mistakes/

### Code comments

- **Obvious comment** — a formal smell in the 11-type inline-comment-smell
  taxonomy (Empirical Software Engineering); the most frequent smell in all
  eight projects studied, 30.8% of the dataset.
  https://link.springer.com/article/10.1007/s10664-023-10425-5
- **"What" comment** — https://luzkan.github.io/smells/what-comment/
- **Excess Structural Information** — the docs-level name (API documentation
  smells, Khan et al.). https://arxiv.org/pdf/2102.08486

### AI-era slang

- **Slop** — Simon Willison: unwanted, unreviewed, unsolicited AI content.
  https://simonwillison.net/2024/May/8/slop/
- **Workslop** — BetterUp/Stanford via HBR: AI output "that masquerades as
  good work, but lacks the substance to meaningfully advance a given task".
  https://hbr.org/2025/09/ai-generated-workslop-is-destroying-productivity
- **AI tells / GPT-ese** — the checklist genre unslop belongs to; the
  structural tell is "the model telegraphing every move".
- **AI smell** — Peter Steinberger: "it's like a feeling, the same as you can
  identify AI-written slop right away" (also names agent-built-UI tells like
  the purple gradient). https://youtu.be/zgNvts_2TUE?t=1718
- **Voice drift** — Sumaiya Shrabony: "generic AI marketing language... It's
  not my voice. It's not your voice. It's nobody's voice."
  https://youtu.be/WLXxTaPagA8?t=316
- **Preamble** — the *positive* term for an agent narrating live tool calls
  so users don't think it froze. The legitimate cousin of this anti-pattern,
  and the likely reason models over-apply narration to static surfaces.
  Counter-position (show streaming work, don't narrate it):
  https://www.builder.io/blog/agent-native-apps

## Linters that already encode the rules

- **aislop** — 50+ deterministic rules, 10 languages: `trivial-comment`,
  `narrative-comment`, `meta-comment`, `csharp-redundant-doc-comment`,
  `todo-stub`. https://github.com/scanaislop/aislop
- **anti-slop** GitHub Action — ~34 checks distilled from 130+ reviewed AI
  slop PRs to large OSS projects: `max-added-comments`,
  `max-description-length`, `max-emoji-count`. https://github.com/peakoss/anti-slop
- **stop-slop** — banned-phrase categories explicitly include
  "meta-commentary". https://github.com/hardikpandya/stop-slop

## Evidence this is an agent-specific defect

- anthropics/claude-code#65961: comments "mostly redundant, restating what
  the adjacent code already makes obvious or simply documenting Claude's
  chain of thought"; CLAUDE.md rules, memory, and hooks all fail to suppress
  it. https://github.com/anthropics/claude-code/issues/65961
- AI review comments average 29.6 tokens per line of code vs 4.1 for humans —
  "AI agents explain from first principles regardless of context".
  https://arxiv.org/pdf/2603.15911
- Anthropic's current system-prompt stance is "match the surrounding code's
  comment density, naming, and idiom" (replacing the old "default to no
  comments") — which is why this skill deletes *restatement*, not comments.
- Agent-written docs produce "vague meta-commentary" like "Follow existing
  patterns in the codebase."
  https://daplab.cs.columbia.edu/general/2026/03/31/your-ai-agent-doesnt-care-about-your-readme.html
- eBay's ReviewDebt flags "AI-authorship indicators" (coauthor footers,
  "generated by" PR-body phrases) and holds that "the author writes the why —
  the agent should not write the PR body". https://youtu.be/TJPInBjhE4Q?t=1232

## Relation to unslop

unslop (vendored here from cursor/plugins, pristine) is prose-level: puffery,
AI vocabulary, punctuation tells, filler. Its rule 27 contains the sharpest
existing form of this skill's portability test: "if the sentence could appear
unchanged in another project's docs, it says nothing about this one. Cut it."
unnarrate applies one level up — text whose entire content is a description of
its own artifact — across UI copy, docs, comments, and commits, then hands the
survivors to unslop.
