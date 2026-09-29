# Sources

- **Scheduling order and Vibe as the second reviewer**: Tom's global
  CLAUDE.md, "Reviews and quotas".
- **Fill every Codex window, credits at weekly 100%**: Tom to the
  localvoxtral scheduler session, 2026-09-28: "we're gonna be using the
  Codex 5-hour limits as soon as they're available with Astra … The goal is
  to not waste limits at all … and to finish the weekly limit". Reset credits
  come only after the weekly limit, soonest-expiring first; two of the three
  credits held that day expired within a week.
- **A credit clears both windows**: CodexBar's credit record, 2026-09-29:
  `"title": "Full reset (Weekly + 5 hr)"`, `"reset_type":
  "codex_rate_limits"`.
- **The Mistral rows**: CodexBar labels the `api` row `Included API` (€25.50
  a month) and the `vibe` row `mistral-monthly-plan` (€255). Both
  `resetsAt` the 1st of the month.
- **z.ai has no weekly window**: CodexBar returns `"secondary": null` for
  the z.ai lite plan.
- **No CLI spend command**: codex-cli 0.156.0 spends a credit only through
  `codex app-server`'s `account/rateLimitResetCredit/consume`, which takes
  `{creditId, idempotencyKey}`. `account/rateLimits/read` lists the credits
  with `expiresAt` (epoch seconds).
- **Origin of the helpers**: `codex-limits` replaces the scheduler's
  `~/bin/codex-reset-credit` (which spent by default) and `orch-codexquota`
  on T0mSIlver/skills#121. `quota-queue` is `orch-queue` from #121 at
  e02a32b, with its two review fixes; it moved here as agreed on #120.
