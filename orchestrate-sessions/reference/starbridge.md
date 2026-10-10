# Evidence behind the Starbridge rules

Mined from the Starbridge orchestrator's transcript and ~260 worker
transcripts, 2026-10-04 to 2026-10-10 (UTC). Counts are lower bounds: the
transcripts were filtered and long lines cut.

| Rule | Count | Examples |
|---|---|---|
| Workers send a line on every answer | ~6 | 2026-10-10: the orchestrator asked Tom in chat to pick device icons after he had answered the session's card ("i already picked"). 2026-10-08 22:18: the desktop session applied four answers ("Menu bar: no count"); at 07:34 the orchestrator asked it for the menu-bar count. The orchestrator: "Not hearing has bitten me more than noise has." |
| `answers --all` at wake-ups | ~7 | 2026-10-06 and 2026-10-08: the mod was not loaded or a `wait` died on an agent restart; Tom's answers sat an hour unseen ("really I haven't answered that? I don't see a starbridge question"). Relaying by hand, the orchestrator once sent d_Cp1AgD1D0xV_P5yB's answer to the wrong session. |
| One asker, `decisions --open` first | ~7 | 2026-10-06 21:43: the orchestrator and the skills session both asked about skills#159's line count. The orchestrator double-posted its own cards ("Tag v0.1.1 from main now?" 08:57 and 09:19 on 10-09) and asked in chat while a card was open (eval token, 10-06 21:21). |
| Never `wait` on another session's card | 1 rule, many runs | 2026-10-06 21:06: "I had told sessions to always run `starbridge wait <id>` in the background." `wait` marks the card waiting, so Tom was notified again for a question meant for the next day. |
| Withdraw with a reason | ~8 | Reposted cards left open: the layout card (d_SMED9QLVGv2LFkLe still open at 20:19 on 10-06), four pairing-QR cards in 7 minutes (10-08 18:22–18:29), the 0.1.3 Play upload card after Tom answered in chat (10-10). An eval on 2026-10-10: Haiku withdrew after an answer in the terminal in 0 of 3 runs without the rule, 3 of 3 with it. |
| Card ids with every claim | ~4 | 2026-10-10 10:34, the hold session: "Correction to my last message: Tom hasn't been asked the 30 s question." The orchestrator had already relayed it. 2026-10-08 11:22: "Tom says he never had a runs mockup card." |
| Briefs never override CLAUDE.md | 8 | Briefs asked for Opus subagent reviews (10-06: #246, #301, #341, #408, demo kit, landing), a cloud session (10-05) and Vibe first (10-05). Each worker followed the brief. |
| One address for the orchestrator | 4 | Workers sent the same handoff to the transcript id `9469cbc4` and to `local_98f3fd9f…` (10-08 08:55, 10:01, 12:33, 21:29). |
| A chip and a card for each batch | 2 rulings | 2026-10-09: "Give me prompts, I'll start these in remote control"; later "I'm at the desktop so no need for prompts". Tom, 2026-10-10: "How could the orchestrator know I'm not at the desktop though?" Remote Control messages land in the same desktop session, and Starbridge presence covers only the machine it runs on. |

Tool loss that changed the flow: Chrome tools returned "Unknown tool" from
2026-10-09 ~21:00 to 2026-10-10 18:09, so the Play submission went through
headless `claude -p --chrome`. The orchestrator hit the 10-message limit on
2026-10-05 20:21. A Remote Control session on another connection could not
be messaged (2026-10-09 01:21).
