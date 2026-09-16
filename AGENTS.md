# AGENTS.md

- Merged changes deploy. My machines install `origin/main` into every agent's
  skills folder every two minutes, so an unmerged edit never runs. To fix an
  installed copy, edit it where it is installed and send it back with
  `skills-pr` ([docs/sync-system.md](docs/sync-system.md)).
- Never edit a directory that contains a `.vendored` stamp. The next update
  replaces it. Send the fix upstream instead
  ([docs/vendoring.md](docs/vendoring.md)).
- To add or remove a skill, also update its plugin in
  `.claude-plugin/marketplace.json` and its row in the README table. A skill
  script that should be on `PATH` also goes in `HELPER_SPECS` in
  `scripts/sync-skills.sh`.
- Every line in a SKILL.md must correct something the model would otherwise
  get wrong. Remove lines the model would follow anyway. Order: happy path,
  then gotchas (symptom, rule, reason), then "Not possible". Keep the body
  around 120 lines and put evidence in `reference/`.
- CI runs `scripts/validate-skills.py`, `scripts/vendor-skills.sh --verify`,
  shellcheck, and `claude plugin validate . --strict`.
