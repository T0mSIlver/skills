# Examples

From T0mSIlver/starbridge's docs reviews, 2026. Project names stay here, not
in the rules.

## One behaviour, one sentence (#1053)

Before, four pages, four wordings: "your tap reaches its session", "carries
on with your answer", "puts each answer into the session". After, one
sentence everywhere: "Your answer comes back as the session's next prompt."

A behaviour shared by several harnesses is defined once, under the support
table, and each harness's section says only "Starbridge races
`AskUserQuestion`." plus what differs.

## One home per fact (#1271)

"What the server sees" was on the README, the overview and the FAQ. Now the
FAQ holds it, and the others say one sentence and link to
`/docs/faq#what-does-the-server-see`.

## Terms (#1047, #1053)

"Harness" for the tool (Claude Code, Codex…), "agent" for the model in it,
"the background service" for the local daemon. The project's docs guide
fixes the order the harnesses are listed in.

## Claims against the code

- "A Codex prompt waits 10 minutes" was 9.5: the constant is 570 000 ms
  (#1271).
- "Backups last 3 weeks" was 2: the backup script keeps 7 days, the offsite
  copy 14 (#761).
- A hold setting documented as opt-in was on by default, with a choice of
  durations, after a release changed its switch to a choice (0.1.7 pass).

## Condition in the cell (#1047)

Cursor's answers went from ✓ to "CLI only": the IDE always needs a manual
wait.

## Versions in examples (0.1.7 pass)

The self-host steps pinned `v0.1.4` three releases later. Now they link the
latest release and show the tag as an example.
