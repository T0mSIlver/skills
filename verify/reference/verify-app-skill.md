# A repo's verify-<app> skill

Adapted from pstack's `create-verification-skill` and
`maintain-verification-skill` (cursor/plugins@99743e9, MIT, Lauren Tan; see
../LICENSE). It lives in the repo, at `.claude/skills/verify-<app>/`, so a
cloud session gets it with the checkout. It is read cold, mid-task, by an
agent that has never seen the app.

## Find the answers in the repo, not from the owner

- **Surface:** what users touch (web UI, mobile app, desktop app, CLI, API).
  One skill per surface that drives differently.
- **Run:** the repo's own dev command, ports, env vars, seed data, auth.
- **Drive:** existing harnesses first (Playwright specs, UI Automator,
  XCUITest, expect scripts, curl), then a generic recipe.
- **Observe:** screenshots, accessibility trees, terminal transcripts,
  response bodies, logs, DB rows.
- **Isolate:** can two runs share the box (ports, data dirs, emulator
  names)? If not, the skill says so and refuses to drive an instance it
  didn't start.

If the checkout doesn't build or start, fix that or report it first.

## Sections of SKILL.md

Frontmatter `name: verify-<app>` and a description naming the app, the
surface and when to use it. Then, each from what the repo really has:

- **Launch:** the exact command from an empty data dir, migrations and seed
  included, and the signal that it is usable (not just that a port answers).
  Teardown.
- **Doctor:** one read-only check: process up, right build, port ours,
  auth valid. Run first, and again after anything surprising.
- **Drive:** real selectors and commands from this repo. Stable handles
  (accessibility labels, test ids, route paths) over coordinates.
- **Fake users:** how to create two or more accounts and devices for
  features that involve more than one, and how to remove them.
- **Evidence:** what to capture and where it goes. The real user path, never
  test-only endpoints or internal setters; the action and the resulting
  state; side effects (rows, files, pushes) as well as the screen.
- **Peers and matrix:** which screens to render at which sizes, themes and
  locales, and which neighbours each element is compared with.
- **Cleanup:** kill only what the run started, by PID; evidence survives.
- **Rules:** checks added by `correct` for mistakes only a render shows
  ("app icon centre within 2 px of the launcher's other icons").

## Feature map

`features/README.md` indexes one file per user-facing feature. Each file
starts with a one-paragraph description and has four sections, in order:

1. `Sub-features`: short ids, one line each.
2. `How to get to it (user POV)`: every entry point.
3. `Driving it with <harness>`: `Preconditions:`, then bullets pairing a
   user action with the exact command and the observable result.
4. `Gotchas`: traps that waste or invalidate a run.

A missing precondition is a reported failure with the reason in Gotchas;
never weaken the journey to make it pass. A proof through one entry point
doesn't cover the others the map lists.

## Prove it, then keep it honest

Before committing: launch, doctor, drive one feature, capture evidence,
clean up, and check the evidence is still there. When a verify run finds
the map wrong (doc drift) or the harness unable to drive working behaviour
(harness gap), fix the skill in its own PR; behaviour that is really broken
is a product bug, reported, never written into the map as normal.
