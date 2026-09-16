#!/usr/bin/env bash
set -Eeuo pipefail

# Restart Remote Control servers that run an older CLI than the `claude`
# launcher, once none of their sessions is mid-turn.
#
# A server spawns every session from its own versioned binary. The native
# updater deletes old versions it does not see locked, and a version lock
# holds a single PID, so a long-running server can lose its binary. From then
# on every spawn fails with ENOENT while systemd still reports the service
# active. See reference/cli-updates.md.

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || true)}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
UNIT_GLOB="${UNIT_GLOB:-claude-rc-*.service}"
# CLI 2.1.258 and older record no session status; such a session counts as
# busy until its transcript has been quiet this long.
QUIET_MINUTES="${QUIET_MINUTES:-15}"

dry_run_in="${DRY_RUN:-}"
case "${dry_run_in//[[:space:]]/}" in
  '' | 0 | [Ff][Aa][Ll][Ss][Ee] | [Nn][Oo]) DRY_RUN="" ;;
  *) DRY_RUN=1 ;;
esac

if [[ -z "$CLAUDE_BIN" || ! -x "$CLAUDE_BIN" ]]; then
  printf 'claude was not found on PATH or is not executable\n' >&2
  exit 1
fi
target="$(readlink -f "$CLAUDE_BIN")"

json_field() {
  sed -n "s/.*\"$1\":\"\\([^\"]*\\)\".*/\\1/p" "$2"
}

cmdline() {
  tr '\0' ' ' 2>/dev/null <"/proc/$1/cmdline"
}

# Field 22 of /proc/PID/stat, counted after the parenthesized command name,
# which may itself contain spaces.
start_time() {
  sed 's/^.*) //' 2>/dev/null <"/proc/$1/stat" | awk '{print $20}'
}

# Succeeds when the session in child process $1 may be mid-turn.
session_busy() {
  local pid="$1" file="$CLAUDE_DIR/sessions/$1.json" status session_id
  [[ -r "$file" ]] || return 0
  # A file left by an earlier process with the same PID says nothing about this one.
  [[ "$(json_field procStart "$file")" == "$(start_time "$pid")" ]] || return 0
  status="$(json_field status "$file")"
  if [[ -n "$status" ]]; then
    [[ "$status" != idle ]]
    return
  fi
  session_id="$(json_field sessionId "$file")"
  [[ -n "$session_id" ]] || return 0
  [[ -n "$(find "$CLAUDE_DIR/projects" -mindepth 2 -maxdepth 2 -name "$session_id.jsonl" -mmin "-$QUIET_MINUTES" -print -quit 2>/dev/null)" ]]
}

mapfile -t units < <(systemctl --user list-units --type=service --state=running --no-legend --plain "$UNIT_GLOB" | awk '{print $1}')

for unit in "${units[@]}"; do
  pid="$(systemctl --user show -p MainPID --value "$unit")"
  [[ "$pid" -gt 0 ]] || continue
  exe="$(readlink "/proc/$pid/exe" 2>/dev/null)" || continue
  [[ "$(cmdline "$pid")" == *" remote-control "* ]] || continue

  state=outdated
  if [[ "$exe" == *" (deleted)" ]]; then
    state=deleted
    exe="${exe% (deleted)}"
  fi
  [[ "$exe" != "$target" || "$state" == deleted ]] || continue
  # Only native installs keep one binary per version; anything else (an npm
  # install runs under node) has no version to fall behind on.
  [[ "$(dirname -- "$exe")" == "$(dirname -- "$target")" ]] || continue

  sessions=0
  busy=0
  while read -r child; do
    [[ "$(cmdline "$child")" == *" --sdk-url "* ]] || continue
    sessions=$((sessions + 1))
    if session_busy "$child"; then
      busy=$((busy + 1))
    fi
  done < <(pgrep -P "$pid" || true)

  from="${exe##*/} ($state)"
  if ((busy > 0)); then
    printf '%s: runs %s, launcher is %s; waiting on %d of %d session(s) mid-turn\n' \
      "$unit" "$from" "${target##*/}" "$busy" "$sessions"
    continue
  fi

  if [[ -n "$DRY_RUN" ]]; then
    printf '%s: would restart from %s onto %s with %d idle session(s)\n' \
      "$unit" "$from" "${target##*/}" "$sessions"
    continue
  fi
  printf '%s: restarting from %s onto %s with %d idle session(s)\n' \
    "$unit" "$from" "${target##*/}" "$sessions"
  systemctl --user restart "$unit" || printf '%s: restart failed\n' "$unit" >&2
done
