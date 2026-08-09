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

On 0.144.1, `codex exec review --base <ref>` re-execs itself with the resolved
SHA in a chain of child processes (3+ levels observed), never emits the
findings block, and leaves stray processes when the wrapper times out — clean
up with `pkill -f "codex exec review"`. The same invocation worked on 0.142.5. Workaround: plain `codex exec -s read-only` in
the branch checkout with a "review the diff between <base-sha> and HEAD"
prompt. Separate 0.142.5 quirk: `--base` cannot be combined with a `[PROMPT]`
argument.

## `codex exec resume` flags and sandbox escalation (0.144.1)

Earlier notes here claimed `resume` rejects all of `-C -m -c -s --json -o`. That
was over-generalized from a single `-s` probe. Retested on 0.144.1
(`codex exec resume --help`, plus live runs):

- **Accepted:** `-m`, `-c`, `--json`, `-o`, `--output-schema`, `--ephemeral`,
  `--ignore-user-config`, `--skip-git-repo-check`, `-i`.
- **Rejected, exit 2:** `-C` and `-s` — `error: unexpected argument '-s' found`.

Resume by id works and keeps context: a baseline run answering `BANANA`,
resumed as `codex exec resume "$thread_id" -m gpt-5.6-luna --json -o r1.md
"What word did you just reply?" < /dev/null`, returned `BANANA`, exit 0. The
`thread_id` from `thread.started` is unchanged across resumes, so it can be
reused for a whole chain.

The consequence of `-s` being rejected is a real privilege escalation, not a
convenience gap. With `sandbox_mode = "danger-full-access"` in
`~/.codex/config.toml`, a session originally launched `-s read-only` and then
resumed with no sandbox flag ran `echo escaped > WROTE.txt` successfully
(`WROTE.txt` created on disk, agent replied `DONE`). The same resume with
`-c sandbox_mode='"read-only"'` refused: agent replied `FAILED` and no file was
created. So `-c sandbox_mode=...` is the working substitute for the rejected
`-s`, and omitting it means the resumed turn inherits the config default rather
than the original run's policy.

Same trap on the model: with `model = "gpt-5.6-terra"` in config, a resume
without `-m` runs terra regardless of what the original run used.

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
