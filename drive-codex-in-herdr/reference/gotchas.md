# Evidence

Observed live on herdr 0.8.0 + codex-cli 0.144.1, 2026-08-09, driving
`gpt-5.6-luna` at `model_reasoning_effort="low"` from a Claude Code session
running inside pane `wW:p1`.

Everything this file once recorded about pane bring-up — the `agent_pane_busy`
race, startup modals reported as `idle`, the hook-trust prompt — was fixed
upstream in herdr 0.8.2 (#2410, #2537, #2773, #2774) and 0.9.0 (#3301, #3632,
#3517), and re-tested clean on 0.9.0 + codex-cli 0.153.4 on 2026-09-08. It is
gone from the skill and from this file. What follows is what still holds.

## An approval runs outside the sandbox

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
what an approval can authorize. `-a never` is what closes that gap.

## A live pane keeps its sandbox across turns

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

## Environment for reference

```
herdr 0.8.0            codex-cli 0.144.1
HERDR_ENV=1  HERDR_PANE_ID=wW:p1  HERDR_SOCKET_PATH=~/.config/herdr/herdr.sock
~/.codex/config.toml:  model = "gpt-5.6-terra"
                       sandbox_mode = "danger-full-access"
                       approval_policy = "never"
```
