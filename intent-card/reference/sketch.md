# Architecture sketch

One per shape, linked from the card (an issue comment or a gist). Adapted
from pstack's `architect` rationale template; the card carries the
comparison, so each sketch stays short.

## Usage, written first

The caller's view: what they import, call and get back, in two or three
real call sites from this repo. The types below are derived from it; when
the two disagree, change the types.

## Shape

Data structures first, then the signatures data flows through, with
`not implemented` bodies and `TODO` pseudocode for the tricky parts. State:

- which invariants the types encode, and where input is validated;
- which module owns each piece of state (one owner each);
- what the public surface hides, and why it is no larger than needed;
- what the system deliberately does not do.

## Designed in, not bolted on

What you would build if the requirement had been there from the start, and
what in today's code it replaces or deletes. A shape that only adds is
suspect: subtract first, so the new sketch is no bigger than the old one
before it grows.

## Costs

Lines added and removed (estimate), new dependencies, migrations, what
breaks for existing data or clients, and what the shape makes hard later.

## Tells that the chosen shape was wrong

Watch for these while building; two of the same kind mean stop and go back
to the card with a new sketch rather than patch around it:

- the same workaround in unrelated places;
- unrelated edge cases that each need a special-case branch;
- types that need casts, `any`, or optional fields that are always set;
- a lock added for state the sketch said was not shared;
- callers that must know the abstraction's internal rules.
