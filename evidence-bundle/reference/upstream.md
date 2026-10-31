# Upstream items: proof in proportion

Why (31 Oct 2026): the owner spent longer verifying small upstream changes
than writing them. The full bundle, an explainer page per PR and fork
"CI only" twins that rehearse upstream CI turned a two-line fix into an
evening, and on llama.cpp #30968 the wait for an answer before opening the
PR let a maintainer write the fix first. The maintainer's review is the
second verifier on an upstream change; the owner's job is to send something
he can explain, not something proven beyond what the maintainer will check.

## Small or large

Small: a comment, an issue, or a PR under about 50 changed lines (tests not
counted) that changes one behaviour. Large: anything else, a new feature, or
a change to an interface or a default other users rely on.

## The five-line note (small items)

Atop the send packet, in place of the explainer page:

1. What broke, as a user sees it.
2. Why, in one sentence about the code.
3. What the fix changes.
4. The test: its name, failing on base and passing on head (run links).
5. The question a maintainer is most likely to ask, with the answer.

## The owner's 15 minutes

1. Can I say what this changes, and why, in two sentences?
2. Did the test fail before and pass after?
3. Does the diff touch only what the issue needs?

Three yeses: send it. A no goes back to the agent, which cuts the change
smaller or splits it. Adding proof does not turn a no into a yes.

## CI

Run the upstream's own CI on the PR itself. Build a fork-only twin only when
the upstream CI can't run the change (a first-time contributor's run waiting
on approval counts) and say so in the note.

## Issue and PR together

Open both, the PR saying "Fixes #n", when the fix is small. Issue first only
when the repo's CONTRIBUTING asks for it, when the fix is a design choice,
or when nobody there knows the owner and the change is large.
