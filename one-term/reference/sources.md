# Sources

Where the rule comes from. Tom's words are quoted as he sent them (some by
voice, so spoken fillers are left in).

## Tom's words

**10 Oct 2026, 18:47 UTC.** Answer to a Starbridge card ("Harness docs page
and landing line: ready to merge?") in the session that wrote
[starbridge#1047](https://github.com/T0mSIlver/starbridge/pull/1047). The
first statement of the rule:

> let's make sure our language in the docs page [...] make sure we use the
> same words, the same language, to say the same thing for different
> harnesses. So if the feature works exactly the same between two harnesses,
> say it exactly the same way, same sentence construction, et cetera. This
> really helps us be more explicit and more clear, in my opinion. [...] At
> the top you define what the harness is, in one sentence is good, but say
> what the question picker is as well. Like, you can name each tool in each
> harness, I think that's fine, but, you know, say "question picker tool,"
> not "question tool." Question picker, question tool, like, be coherent with
> the language, you know. And yeah, when the feature is the same, say it the
> same way, no need to reword it. And, yeah, let's be clear: this is
> documentation, it has to be totally unambiguous.

**10 Oct 2026, 18:52 UTC.** Next card, same session:

> Then with this change in wording, same behavior, same sentence, let's do a
> pass over the rest of the docs.

That pass became
[starbridge#1053](https://github.com/T0mSIlver/starbridge/pull/1053).

**21 Oct 2026, 17:42 UTC.** Comment on a course page for
[Blaizzy/mlx-audio-swift#271](https://github.com/Blaizzy/mlx-audio-swift/pull/271),
on the draft reply "The first melColumns call would materialize it anyway,
but evaluating it in periodicHannWindow keeps that cost out of the first
append":

> Let's use one behavior = one term so don't say the first call and the
> first append

Same day, asking for this skill: "describe things one way, don't use
synonyms, don't paraphrase. The goal is to stay coherent. If we use a
slightly different term, it's because we're using it in a different context
or there's a concrete reason to do this."

## Where it is already written down

| Where | Text | Since |
|---|---|---|
| starbridge `docs/AGENTS.md`, Terms | "Keep one name per thing" and a shared sentence "copied word for word" | #1273, 11 Oct |
| starbridge `DESIGN.md`, Settings | "One name per setting on every client" | #1061, 10 Oct |
| `docs-review` step 4 | "Say each behaviour in one sentence" | skills #188, 13 Oct |
| `docs/cloud-CLAUDE.md` and Tom's `~/.claude/CLAUDE.md` | "Keep one name per thing." | |
| `unslop` 11 (vendored) | "Synonym cycling [...] Pick one, repeat it." | |

Those lines are scoped to docs, settings or style. This skill is the rule
for any text, with the exceptions Tom named: a different context or a
concrete reason.

## Outside

- Matt Pocock, `writing-for-agents`: synonyms for one case are duplication.
  https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-for-agents/SKILL.md
- Google developer documentation style guide: consistency within a document
  over any single rule. https://developers.google.com/style/highlights
