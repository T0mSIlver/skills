# Codex delegation — evidence and full mechanics

Details behind the one-line gotchas in SKILL.md. Versions named where behavior
is version-specific; re-verify on newer CLIs.

## Stdin wedge (verified 0.142.5)

`codex exec` reads stdin at startup when you pass `-`, no prompt at all, or a
prompt *argument* while stdin is piped — in the argument case it appends stdin
as a `<stdin>` block after printing `Reading additional input from stdin...`.
Under a non-interactive harness (Claude Code Bash tool, cron, orchestrators)
stdin is an open pipe that never closes, so codex blocks until EOF before ever
contacting the model. A/B proof: `codex exec "hi" < <(sleep 60)` wedges at
"Reading additional input from stdin"; `codex exec "hi" < /dev/null` proceeds.
`resume` and `review` did not append piped stdin on 0.142.5, but redirecting is
harmless and future-proof. A cheap wedge probe for any CLI: run under a
throwaway `CODEX_HOME=$(mktemp -d)` so auth fails fast — a wedge is 0% CPU and
no network attempt; a healthy run reaches auth/network errors.

## Linked-worktree git metadata (2026-07)

A linked worktree's admin dir lives under the parent repo's
`.git/worktrees/<name>` — outside the sandbox's writable roots — so `git
commit` and `git merge` fail even with `-C <worktree>` and
`--sandbox workspace-write`. A worker asked to merge will content-merge the
working tree and leave no merge commit, forcing `-s ours` surgery later.
Division of labor: orchestrator runs `git merge` and leaves the conflicted
tree; worker resolves file content only; orchestrator commits.

Bundle fallback (verified lossless in practice): brief the worker "commit; if
commit fails, produce a `git bundle` of the exact final tree as logical
commits", then:

```bash
git fetch <bundle-file> <branch>
git reset --hard <bundle-head>
```

## `codex exec review` recursion (0.144.1 regression)

After the 0.142.5 → 0.144.1 auto-update, `codex exec review --base <ref>`
re-execs itself with the resolved SHA in a chain of child processes (3+ levels
observed), never emits the findings block, and leaves stray processes when the
wrapper times out — clean up with `pkill -f "codex exec review"`. The same
invocation worked on 0.142.5. Workaround: plain `codex exec -s read-only` in
the branch checkout with a "review the diff between <base-sha> and HEAD"
prompt. Separate 0.142.5 quirk: `--base` cannot be combined with a `[PROMPT]`
argument.

## `codex exec resume` flag rejection (0.142.x–0.144.1)

`codex exec resume` rejects `-C`, `-m`, `-c`, `-s`, `--json`, `-o` with a usage
error, exit 2 (zero-token probe:
`CODEX_HOME=$(mktemp -d) codex exec resume --last -s read-only "hi" < /dev/null`).
Resumed turns therefore run with config-file defaults, not the original
launch's flags. When a follow-up needs a specific model, sandbox, or output
capture, launch a fresh `codex exec` whose prompt embeds the prior finding and
the fix diff.

## User-config MCP crashes

A configured MCP server that fails (e.g. auth) kills the whole session — seen
as `rmcp transport worker quit with fatal AuthRequired`. `--ignore-user-config`
skips `~/.codex/config.toml`; auth still resolves via `CODEX_HOME`, so login
survives, but model/profile settings are dropped — re-specify `-m` and
`-c model_reasoning_effort=...` on the CLI.

## Long-run behavior

- The Claude Code Bash tool's foreground timeout kills long runs; keep prompts
  self-contained enough to finish, or run in the background and wait for the
  completion notification.
- Front-loading the actual code into the prompt (answer-in-first-turn, zero
  exploration) makes high-effort runs materially more reliable; running in an
  empty scratch dir with `--skip-git-repo-check` keeps the model from
  wandering.
- `--json` writes JSONL events to stdout; `-o <file>` additionally writes the
  final answer as a plain file. Parse `thread.started` for the session id.
