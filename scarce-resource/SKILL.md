---
name: scarce-resource
description: "Schedule a scarce shared resource (a self-hosted CI runner, a GPU, the owner's machine) for many sessions: book heavy runs into the owner's night window, wake up on time, dispatch one workflow run at a time, wait until the resource is idle, greenlight PR readies by the lanes they will run, and protect the owner's data before runs on their machine. Use when asked to book the runner or GPU, run something tonight, plan the night window, or dispatch evals or benches."
compatibility: gh and bash. The orch-* scripts are on PATH (else in the orchestrate-sessions skill's scripts/) and read ~/.config/orchestrate/<repo>.env.
---

# Scarce resource

- **Windows.** Heavy runs go in the owner's window. Keep a numbered night
  plan in memory: order, pass criterion, who acts on the result, and which
  step drops first when time runs short. Plan it from
  `gh pr list --label waits:<lane>`.
- **Wake-ups.** Session crons don't fire while the session is idle. Run
  `orch-wakeat "YYYY-MM-DD HH:MM"` in the background; its exit wakes you. A
  dispatch that must happen even if the session is gone goes in a systemd
  user timer that refuses outside the window.
- **One dispatch at a time.** A concurrency group without cancel-in-progress
  keeps one pending run; a second dispatch replaces it. Chain
  `orch-dispatch <workflow> <ref>`, which exits once its run has started.
  `orch-idlewait` exits when no `RESOURCE_JOBS` job is queued or running;
  `orch-runwait <run-id>…` when the first listed run completes.
- **Greenlight.** Before saying go to a `gh pr ready`, ask which lanes the
  head will run: one that needs the resource waits for its window unless a
  waiver is in both the PR body and the head commit message.
- **Before a window,** run `orch-conflicts`: a PR that conflicts with main
  gets no workflow run, so a ready or a dispatch on it does nothing.
- **A runner on the owner's machine runs as the owner** and reaches their
  real data. Check their backups are fresh before a night of runs there.

## Gotchas

- **A dispatch runs the workflow file of the ref**, so an old branch runs
  the old workflow.
- **A merge commit drops a waiver** that lived only in an earlier commit
  message; put the marker in the merge commit or the PR body.
- **Times** in UTC with the owner's offset; `date -u` for stored timestamps.

`../orchestrate-sessions/reference/worked-example.md` shows one self-hosted
Mac runner scheduled this way; the evidence is in
`../orchestrate-sessions/reference/incidents.md`.
