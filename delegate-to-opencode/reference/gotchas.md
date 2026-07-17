# opencode delegation — evidence and full mechanics

Details behind the one-line gotchas in SKILL.md. Verified on opencode
1.17.12/1.17.13 with zai-coding-plan/glm-5.2; re-verify on newer versions.

## Stdin wedge at `init`

`opencode run` reads stdin at startup. Under a non-interactive harness (Claude
Code Bash tool, cron, orchestrators) stdin is an open pipe/socket that never
sends data and never closes, so opencode blocks in its event loop
(`epoll_wait` on fd 0) before any session is created or the model contacted.
Symptoms: `events.jsonl` 0 bytes from the very start, the shared log ends at
`init` with no `created id=ses_...`, the process idle at ~0% CPU holding fd 0,
no outbound TCP. Confirmed by A/B: the identical command hangs without
`< /dev/null` and completes with it. Resume forms (`--continue`,
`--session <id>`) are still `opencode run` and need the redirect just as much.

## Silent stalls and the timeout wrapper

opencode has no stream timeout. Explicit provider errors ("service temporarily
overloaded") are retried fine; a provider-side *silent* SSE stall leaves the
process waiting indefinitely — observed as multi-hour zombies at ~0% CPU with
zero further output after streaming normally for hours. `timeout
--signal=TERM 2700` converts that into a clean failure the orchestrator can
detect and relaunch. Health signal during a run: a healthy `--format json`
run streams events continuously; 0 bytes after ~5 min or mtime stale >10 min
means hung.

## Concurrency

Single field observation (2026-07-03, opencode 1.17.13, one machine): with two
instances running, a third hung at startup with zero log entries, blocked
before its first log write on the shared SQLite/WAL state at
`~/.local/share/opencode/opencode.db` held by the running instances. This is
not a documented opencode limit — treat "stagger past two" as a conservative
heuristic and re-test on newer versions. The tell for this failure mode is a
startup hang with an empty log, as opposed to a mid-stream stall.

## The 32k output-token clamp

opencode hardcodes `OUTPUT_TOKEN_MAX = 32_000` and applies
`Math.min(model.limit.output, OUTPUT_TOKEN_MAX)`, clamping glm-5.2's real
131,072-token output limit. Reasoning tokens bill against the same budget, so
a thinking-heavy brief can spend the entire 32k on hidden reasoning and emit no
visible answer. The failure is silent: the provider reports `finish_reason:
"length"`, opencode surfaces `reason: "length"` on a `step_finish` part,
raises no error, and exits 0 (`MessageOutputLengthError` exists in the schema
but is never constructed; `"length"` is missing from the `modelFinished`
exclusion list). A/B on 1.17.12: with the env var set to `1`, `reason:
"length"`, no text, exit 0; unset, full answer with `reason: "stop"`.

`OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX` must be a positive integer (silently
ignored otherwise), needs no `OPENCODE_EXPERIMENTAL=1`, and only raises the cap
toward the model's own ceiling — oversized values are harmless but pointless.
Look ceilings up under `limit.output` at `https://models.dev/api.json`
(`opencode models` doesn't print it).

Context trade-off: for models with `limit.output` but no `limit.input` —
glm-5.2 included — usable context is computed as `context - maxOutputTokens`,
and `compaction.reserved` does not override that branch. At glm-5.2's 1M
context the loss is noise (968,000 → 868,928 usable). On a 200k-context model
the same 131,072 would cut usable context to ~69k and trigger compaction far
earlier. Match the value to the model.

## `--file` failure modes (verified 1.17.12 and 1.17.13)

`--file` is an attachment flag (`run.ts` declares it `array: true`); a
non-empty positional message is always required. Three verified failures:
`--file prompt.md` alone dies with `You must provide a message or a command`;
`--file prompt.md "do X"` and `--file=prompt.md "do X"` both swallow the
message into the file list (yargs greedy array) and die with
`File not found: do X`. Safe forms: inline `"$(cat prompt.md)"`, or message
BEFORE the flag: `opencode run "Follow the attached prompt file exactly."
--file prompt.md`. Briefs that could start with `-` need the quoted inline form.

## Dead-run recovery

When the timeout kills a stalled edit worker (or it dies mid-run), its edits
are already on disk in the worktree, uncommitted. Hand the worktree to a fresh
run — same or different vendor — with a continue-brief: read the original
prompt file and `git diff`, judge the partial work critically rather than
assuming it is correct, finish, verify, report. This beats resuming a session
whose provider stream already zombied.
