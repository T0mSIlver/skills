# Evidence behind "Reaching the owner"

From the Starbridge orchestrator on T0mSIlver/starbridge, 2026-10-06, the
first night its owner ran everything through Starbridge. Starbridge posts an
agent's question as a card on the owner's phone and brings the answer back
into the session that asked.

| Rule | What happened |
|---|---|
| Everything that needs the owner is a card | The owner answers only from his phone. 2026-10-06, he asked for the orchestration skill to integrate Starbridge, "maximum dogfooding": decisions, status and work waiting on him go as cards, and the Needs You page stays as the fallback. |
| The orchestrator follows every answer itself | Sessions asked their own questions. The orchestrator learned the answers only when a session relayed them, and missed several, until it polled Starbridge's state file (`~/.config/starbridge/state.json`) from a scratch script. `starbridge answers --all --follow` (starbridge#629) replaces that script. |
| Check that the session got its answer | `ask` printed "The answer will come back into this session as a new prompt" from a Claude Code session whose Starbridge plugin had not loaded (starbridge#537, fixed by starbridge#589). Nothing delivered the answers, and the session sat idle with them. |
| `wait --no-mark` for answers that block nothing yet | A session posted "Tomorrow: how did the Windows VM test go?" and ran `starbridge wait <id>` in the background. `wait <id>` marks the card waiting, which notified the owner a second time after he had dismissed the first (starbridge#603; `--no-mark` in starbridge#605). The `starbridge` skill now says when to use it. |
| Chip prompts carry the rule | Same request: the sessions the orchestrator spawns dogfood Starbridge too, and a chip starts from its prompt alone. |
