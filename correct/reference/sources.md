# Sources

- The owner's charter: "A correction I make twice becomes a check (lint,
  test, type or verifier rule) that fails on the old mistake, so I never
  make it a third time." The plan of 2026-10-16 adds findings a reviewer or
  verifier sees twice, and the rule → enforcer table in AGENTS.md where a
  rule with no enforcer is an open item.
- Why: in Starbridge (4–15 Oct 2026) the owner's corrections stayed
  corrections. None became a check, so the same classes came back: an
  off-centre icon in four PRs, about 25 copy problems, Settings subtitles,
  stale docs, unrequested pages.
- pstack `correct` (cursor/plugins@99743e9, MIT, Lauren Tan): the agent
  that copies the nearest example, fixing at the highest level, lint
  messages that name the fix, failing only on additions, proving each check
  on a real past mistake, exceptions on the line, the rule table. Changed
  here: it runs on each correction rather than as a repo-wide campaign, a
  first occurrence gets a "none yet" row, and a verifier rule sits between
  test and doc for mistakes only a render shows.
