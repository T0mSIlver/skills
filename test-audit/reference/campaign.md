# Pruning a whole subsystem

A campaign prunes one subsystem's entire test surface (a plugin, a package, a
core area) in one PR. The gate, retention bar and evidence rules in
[SKILL.md](../SKILL.md) apply throughout. Each step ends on its completion
criterion; don't start the next one early. The examples come from OpenClaw's
Telegram campaign.

## 1. Baseline

Pin a base-branch SHA. Record the subsystem's test and test-support line
counts and every test file's pass/fail state. Keep base failures in their own
list: in the Telegram campaign all three were real delivery bugs, not stale
tests.

Done when every in-scope test file has a recorded result.

## 2. Lanes

Split the surface into lanes along production ownership, not file-name
prefixes. Telegram's were accounts, commands, context, dispatch, inbound,
outbound, persistence, transport, shared, harness and live scenarios. Include
the subsystem's cases in shared core suites and its end-to-end harness.

Done when every test file and scenario belongs to exactly one lane.

## 3. Read-only ledger per lane

One read-only agent per lane reads every assigned test in full, including
parameter tables, plus the production code, callers, history and CI routing.
Each test declaration gets one mark and one evidence line in a written
ledger. A parameterized test is one declaration unless its rows need
different marks.

- `R` retain: name the contract and the bug it catches;
- `F` fix: keep the contract, repair the assertion (for example a negative
  test that passes when only one of several items is missing);
- `C` consolidate: name the test that absorbs the assertion;
- `D` delete: name the proof that remains, or why there is no contract.

Done when every declaration has a mark and an evidence line.

## 4. Layer plan per lane

The ledger is input, not the edit list. A second read-only pass looks for a
redundant layer: in Telegram, several dispatch suites replayed the same shared
compositor through one mocked preview, around stronger suites that used a real
stream and HTTP fixtures. Name the keeper suite for each contract. Prefer the
real transport with a fake network over a mocked collaborator. Correct ledger
errors this pass finds.

Done when each lane plan names its retired files, its keeper per contract, the
assertions to carry into keepers, and the test-only production seams
unlocked.

## 5. Cutover

Edit lane by lane. Route changes to shared harnesses and support files
through one owner, one at a time. With each lane, remove the test-only
production seams it unlocks: injection parameters, getters, reset exports,
indirection layers. Register moved suites in CI routing. Put durable
test-ownership rules in the subsystem's `AGENTS.md`, drawn from mistakes the
campaign actually found.

Done when every lane plan is applied and each lane's keepers pass.

## 6. Preservation review

Before claiming completion, independent reviewers, one per boundary group,
compare deleted coverage against the keepers. They look for contracts that
lost their only proof, and for new assertions that can't fail. The Telegram
review found nine real gaps and one unreachable assertion.

For each restored contract, make one deliberate mutation of the production
code and confirm the keeper goes red. Then restore the source byte for byte.

Done when every gap is restored or rejected with source evidence, and every
restored contract has a caught mutation.

## 7. Product defects

A base failure that survives into a keeper is a bug. Fix it in the production
code as a separate commit, proven through the real user flow, with a control
run that reverts the fix and shows the old behavior. Record unrelated
defects as follow-ups instead of fixing them in the campaign.

Done when each fix has a failing control and a passing candidate on the same
harness.

## 8. Reconcile and hand off

A campaign outlives many base-branch commits. Merge the base branch rather
than rebasing a long campaign. When the base modified a file the campaign
deleted, keep the deletion and port the new contract into the keeper. Confirm
every regression test added upstream still has a home. Rerun the subsystem
suite and the live checks on the merged head.

Review tooling may truncate the file list on a diff this large; say so in the
PR.

Hand off with the [junk-patterns.md](junk-patterns.md#handoff) report, plus:

- base and final test and support line counts, production counted separately;
- lanes, retired layers and keepers;
- preservation gaps found and the mutations that proved them;
- product defects with control and candidate runs.
