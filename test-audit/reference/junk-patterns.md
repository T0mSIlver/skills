# Junk patterns, retention bar, candidate evidence

## Junk patterns

A match fails the gate for a new test, and makes an existing test a deletion
candidate, unless the retention bar below names a contract it independently
guards.

- Assertion-free coverage probes: the test can fail only through a crash,
  panic or missing selector.
- Self-comparisons and identity copies: setup and assertion share one object.
- Expected values produced by the helper, builder or renderer under test, or
  hidden behind loops that recompute them.
- Change detectors: only an intentional decision (a constant, exact message
  wording, private structure) can fail the test.
- Copied fixtures, inventories, manifests or export lists that restate the
  source.
- Exact source, import or string greps, and tests that a removed symbol stays
  removed.
- Tests of private predicates or call shapes that a real boundary already
  covers.
- The same contract invoked twice, or a shared helper replayed in each
  consumer's suite.
- Tests whose only purpose is keeping a test-only export, global or wrapper
  alive, and production code whose only callers are tests.
- Tests of the framework or a well-established library, rather than your
  contract at its boundary.
- Tests that only restate the agent's own new helper, written to validate the
  change that added it.
- Mocks that implement the behavior under assertion, or one identical mock
  standing in for different APIs.
- Assertions on the mock itself (a `*-mock` test ID, a spy that only the mock
  calls).
- Fixtures that supply the result, ordering or callback the production code
  should produce, or persistence asserted against a store the path never
  writes.
- Capability tests that restate a declared flag instead of exercising what
  the flag promises.
- Negative controls that pass for an unrelated reason: a denial from a
  different guard, or a rejection the production path never reaches.
- Names or fixtures that promise more than the input exercises.
- Mock setup that is more than half the test, or mocking "just to be safe".

## Retention bar

Keep a test when it independently enforces a public API, SDK, protocol,
config, migration, storage, security, platform, default, prompt-byte,
generated cross-language, package, release or architecture contract. Also
keep:

- call-ordering assertions when the order is observable behavior;
- regressions with a credible failure mode;
- source inspection when it is the cheapest independent guard: it fails when
  the contract changes (the user-facing key, byte or path) and survives an
  identifier-only rename;
- a narrow characterization test naming an upstream behavior that genuinely
  surprised someone;
- a retained test that fails on the base branch: treat it as a product bug
  and repair the owner.

A test that must change when source is reorganized without changing behavior
is suspect, not automatically deletable. It may still be the only independent
proof of a contract; prove otherwise before removing it.

## Candidate evidence

Record every field before editing:

- exact test name and location;
- what failure it can actually detect;
- non-test callers of the production code or test-support seam it covers;
- the stronger test that still proves the contract, or why no contract
  exists;
- history: why the test or seam was added;
- production or test-support code the deletion unlocks;
- risk, and the focused command that validates the change.

## Handoff

Report:

- the categories of low-value tests removed, and why they existed;
- production simplifications the deletions unlocked;
- tests that matched a junk pattern but were kept, and the contract each
  guards;
- which tests and gates actually ran;
- production versus test line counts;
- PR state and named follow-ups.
