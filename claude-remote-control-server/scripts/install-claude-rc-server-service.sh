#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -z "${REPO_DIR:-}" ]]; then
  if git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_DIR="$(git -C "$PWD" rev-parse --show-toplevel)"
  else
    REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
  fi
fi
REPO_DIR="$(cd "$REPO_DIR" && pwd -P)"
REPO_NAME="$(basename "$REPO_DIR")"
SERVICE_NAME="${SERVICE_NAME:-claude-rc-$REPO_NAME}"
HOST_NAME="$(hostname -s 2>/dev/null || echo localhost)"
SESSION_NAME="${SESSION_NAME:-$REPO_NAME@$HOST_NAME}"
SESSION_PREFIX="${SESSION_PREFIX:-$HOST_NAME-$REPO_NAME}"
CAPACITY="${CAPACITY:-8}"
PERMISSION_MODE="${PERMISSION_MODE:-}"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude)}"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE_PATH="$SYSTEMD_USER_DIR/$SERVICE_NAME.service"
# One timer for all servers restarts any left on an old CLI once idle. The
# script is copied out of SCRIPT_DIR because a plugin install's directory
# changes path on every plugin update.
REFRESH_SOURCE="$SCRIPT_DIR/refresh-claude-rc-servers.sh"
REFRESH_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/claude-rc/refresh-claude-rc-servers.sh"
REFRESH_UNIT=claude-rc-refresh

# DRY_RUN prints the unit to stdout and touches nothing. 0/false/no read as off
# so `DRY_RUN=0` cannot silently install; matched case- and space-insensitively
# so `False` disables rather than surprising into a dry run.
dry_run_in="${DRY_RUN:-}"
case "${dry_run_in//[[:space:]]/}" in
  '' | 0 | [Ff][Aa][Ll][Ss][Ee] | [Nn][Oo]) DRY_RUN="" ;;
  *) DRY_RUN=1 ;;
esac

if [[ -z "$DRY_RUN" ]]; then
  if ! command -v systemctl >/dev/null 2>&1; then
    printf 'systemctl was not found; install another process supervisor for claude remote-control\n' >&2
    exit 1
  fi

  if ! command -v loginctl >/dev/null 2>&1; then
    printf 'loginctl was not found; cannot enable user lingering automatically\n' >&2
    exit 1
  fi
fi

if [[ -z "$CLAUDE_BIN" || ! -x "$CLAUDE_BIN" ]]; then
  printf 'claude was not found on PATH or is not executable\n' >&2
  exit 1
fi

if ! git -C "$REPO_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  printf 'not a git checkout: %s\n' "$REPO_DIR" >&2
  exit 1
fi

# Optional --permission-mode for sessions this server spawns. Validated here
# so a typo fails the install instead of crash-looping the service later.
PERMISSION_MODE_ARG=""
if [[ -n "$PERMISSION_MODE" ]]; then
  case "$PERMISSION_MODE" in
    acceptEdits | auto | bypassPermissions | manual | dontAsk | plan | default) ;;
    *)
      printf 'unsupported PERMISSION_MODE: %s\n' "$PERMISSION_MODE" >&2
      printf 'expected one of: acceptEdits auto bypassPermissions manual dontAsk plan\n' >&2
      exit 1
      ;;
  esac
  PERMISSION_MODE_ARG=" --permission-mode $PERMISSION_MODE"
fi

service_tmp="$(mktemp)"
refresh_service_tmp="$(mktemp)"
refresh_timer_tmp="$(mktemp)"
trap 'rm -f "$service_tmp" "$refresh_service_tmp" "$refresh_timer_tmp"' EXIT

cat >"$service_tmp" <<UNIT
[Unit]
Description=Claude Code Remote Control server for $REPO_NAME
Documentation=https://code.claude.com/docs/en/remote-control
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=$REPO_DIR
Environment=HOME=$HOME
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/env -u CLAUDE_CODE_OAUTH_TOKEN -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL $CLAUDE_BIN remote-control --name "$SESSION_NAME" --remote-control-session-name-prefix "$SESSION_PREFIX" --spawn worktree --capacity $CAPACITY$PERMISSION_MODE_ARG
Restart=always
RestartSec=30

[Install]
WantedBy=default.target
UNIT

cat >"$refresh_service_tmp" <<UNIT
[Unit]
Description=Restart Claude Code Remote Control servers left on an old CLI

[Service]
Type=oneshot
Environment=CLAUDE_BIN=$CLAUDE_BIN
ExecStart=$REFRESH_PATH
UNIT

cat >"$refresh_timer_tmp" <<UNIT
[Unit]
Description=Check Claude Code Remote Control servers for an old CLI

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
UNIT

if [[ -n "$DRY_RUN" ]]; then
  printf 'dry run: would write %s and run systemctl --user enable --now %s.service\n' \
    "$SERVICE_PATH" "$SERVICE_NAME" >&2
  printf 'dry run: would copy %s to %s and enable %s.timer\n' \
    "$REFRESH_SOURCE" "$REFRESH_PATH" "$REFRESH_UNIT" >&2
  cat "$service_tmp"
  exit 0
fi

mkdir -p "$SYSTEMD_USER_DIR"
install -m 0644 "$service_tmp" "$SERVICE_PATH"

refresh=""
if [[ -f "$REFRESH_SOURCE" ]]; then
  refresh=1
  install -D -m 0755 "$REFRESH_SOURCE" "$REFRESH_PATH"
  install -m 0644 "$refresh_service_tmp" "$SYSTEMD_USER_DIR/$REFRESH_UNIT.service"
  install -m 0644 "$refresh_timer_tmp" "$SYSTEMD_USER_DIR/$REFRESH_UNIT.timer"
else
  printf 'warning: %s not found; servers will not be restarted after CLI updates\n' \
    "$REFRESH_SOURCE" >&2
fi

systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME.service"
if [[ -n "$refresh" ]]; then
  systemctl --user enable --now "$REFRESH_UNIT.timer"
fi

if loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q '^Linger=no$'; then
  sudo loginctl enable-linger "$USER"
fi

systemctl --user --no-pager status "$SERVICE_NAME.service"
