# Evidence

All observed live on herdr 0.8.0 + codex-cli 0.144.1, 2026-08-09, driving
`gpt-5.6-luna` at `model_reasoning_effort="low"` from a Claude Code session
running inside pane `wW:p1`.

## `pane split` returns before the shell is usable

```
$ herdr pane split --current --direction right --cwd "$d" --no-focus
{"result":{"pane":{"pane_id":"wW:p3", ...}}}
$ herdr agent start codextest --kind codex --pane wW:p3 -- -m gpt-5.6-luna
{"error":{"code":"agent_pane_busy","message":"agent target pane wW:p3 is not an available shell"}}
```

Seconds later the same pane was fine, and `pane process-info` showed only the
shell:

```json
{"foreground_processes":[{"argv":["/usr/bin/zsh"],"pid":3370487}],"shell_pid":3370487}
```

That looked like a readiness predicate, and the first version of the helper
polled it. **It does not work.** On a clean run the pid check passed and
`agent start` still returned `agent_pane_busy` — herdr's "available shell" test
is stricter than "no foreground child", and the gap is not observable from
`process-info`. The helper now retries `agent start` on `agent_pane_busy`
instead of predicting readiness, and treats every other error as fatal.

Corollary found the same way: the failing run left pane `wW:p5` orphaned,
because `pane split` had already succeeded. Every error path after the split
must close the pane.

## Startup modals are reported as `idle`

First live attempt, immediately after a successful `agent start` that returned
`"agent_status":"idle","interactive_ready":true`:

```
$ herdr agent prompt codextest "Reply with exactly the word BANANA..." --wait
{"error":{"code":"agent_prompt_stalled","message":"agent prompt produced no observed
 state change within 5000 ms; status is idle and state_change_seq remained 929"}}
$ herdr agent read codextest --source detection
  3. Continue without trusting (hooks won't run)
  Press enter to confirm or esc to go back
```

The prompt text and its Enter had gone into a hook-trust dialog. The *second*
prompt then returned exit 0 with `"agent_status":"done"` while the screen was
still the same dialog — proof that neither the exit status nor the status field
distinguishes "answered my prompt" from "pressed a key in a modal".

Two distinct modals were seen on this machine, in order:

```
  ✨ Update available! 0.144.1 -> 0.147.0
› 1. Update now   2. Skip   3. Skip until next version
```
```
  Hooks need review — 1 hook is new or changed.
› 1. Review hooks   2. Trust all and continue   3. Continue without trusting
```

The hook is herdr's own integration, `~/.codex/hooks.json` →
`bash '/home/dev/.codex/herdr-agent-state.sh' session`, installed by
`herdr integration install codex`. Trusting it clears the modal permanently and
switches codex from screen-manifest inference to hook-reported state.

The reliable "composer is live" marker is the footer line, absent from every
modal screen:

```
  gpt-5.6-luna low · /tmp/…/scratchpad/herdr-test
```

## Multi-turn continuation keeps model, sandbox and context

Three consecutive `agent prompt --wait` calls against one agent named
`codextest`, launched `-s read-only`:

| turn | prompt | reply |
|---|---|---|
| 1 | reply with exactly BANANA | `• BANANA` |
| 2 | what word did you just reply? | `• BANANA` |
| 3 | run `echo escaped > WROTE3.txt` | `• FAILED`, no file on disk |

Turn 3 is the contrast with `codex exec resume`: the same instruction, issued to
a resumed *exec* thread that had also been launched `-s read-only`, **wrote the
file** because resume rejects `-s` and falls back to the config's
`sandbox_mode = "danger-full-access"`. In the herdr pane the original sandbox is
still the live process's own policy, so it held.

## `blocked` detection and answering it

Launched with `-s read-only -a on-request`, then asked to create a file:

```
$ herdr agent prompt worker "Create a file named APPROVED.txt ..." --wait --timeout 180000
$ herdr agent get worker | jq -c '.result.agent | {agent_status, interactive_ready}'
{"agent_status":"blocked","interactive_ready":true}
```

Screen at that moment:

```
  Would you like to run the following command?
  Environment: local
  $ printf 'yes\n' > APPROVED.txt
› 1. Yes, proceed (y)
  2. Yes, and don't ask again ... (p)
  3. No, and tell Codex what to do differently (esc)
```

`herdr agent send-keys worker enter` → `herdr agent wait worker --until idle
--until done` returned `idle`, and `APPROVED.txt` existed on disk.

Note `Environment: local`: the approved command ran **outside** the read-only
sandbox. `-s read-only` bounds what codex does unattended; it does not bound
what an approval can authorize.

## Reading long output

A 120-line reply was fully recoverable:

```
$ herdr agent read worker --source recent-unwrapped --lines 400 > long.txt
$ sed -n '70,73p' long.txt
• 1
  2
  3
```

195 lines came back, including shell prompt chrome, the codex banner box, and
MCP warnings. It works, but it is a scroll pass and a lot of non-payload tokens;
a file handoff is better for anything that matters.

## Environment for reference

```
herdr 0.8.0            codex-cli 0.144.1
HERDR_ENV=1  HERDR_PANE_ID=wW:p1  HERDR_SOCKET_PATH=~/.config/herdr/herdr.sock
~/.codex/config.toml:  model = "gpt-5.6-terra"
                       sandbox_mode = "danger-full-access"
                       approval_policy = "never"
```
