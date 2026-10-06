# Evidence behind "Reaching the owner"

From the Starbridge orchestrator on T0mSIlver/starbridge, 2026-10-06, the
first night its owner ran everything through Starbridge. Starbridge posts an
agent's question as a card on the owner's phone and brings the answer back
into the session that asked.

| Rule | What happened |
|---|---|
| Everything that needs the owner is a card | The owner answers only from his phone. 2026-10-06, he asked for the orchestration skill to integrate Starbridge, "maximum dogfooding": decisions, status and work waiting on him go as cards, and the Needs You page stays as the fallback. |
| The orchestrator follows every answer itself (the owner's account of the night, 2026-10-06) | Sessions asked their own questions. The orchestrator learned the answers only when a session relayed them, and missed several, until it polled Starbridge's state file (`~/.config/starbridge/state.json`) from a scratch script. `starbridge answers --all --follow` (starbridge#629, PR starbridge#633) replaces that script once released. |
| Check that the session got its answer | `ask` printed "The answer will come back into this session as a new prompt" from a Claude Code session whose Starbridge plugin had not loaded (starbridge#537; the fix, starbridge#589, was still open that night). Nothing delivered the answers, and the session sat idle with them. |
| `wait --no-mark` for answers that block nothing yet | A session posted "Tomorrow: how did the Windows VM test go?" and ran `starbridge wait <id>` in the background. `wait <id>` marks the card waiting, which notified the owner a second time after he had dismissed the first (starbridge#603; `--no-mark` in starbridge#605). Starbridge's own skill (`plugin/skills/starbridge/SKILL.md` on main) now says when to use it; the copy vendored here gets it at the next pin. |
| Chip prompts carry the rule | Same request: the sessions the orchestrator spawns dogfood Starbridge too, and a chip starts from its prompt alone. |
| One asker per question | Later that night the orchestrator and the session that owned skills#159 each sent the owner a card asking to accept its 134-line SKILL.md, so he read the same question twice, the opposite of what Starbridge is for. `starbridge decisions --open` (added to starbridge#633) lists the open questions with the session that asked. |
| Approval for the line count | The owner accepted orchestrate-sessions at 134 lines, over the 120-line limit, for skills#159 (2026-10-06). |
