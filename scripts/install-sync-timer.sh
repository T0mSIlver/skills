#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SYNC_SCRIPT="$REPO_DIR/scripts/sync-skills.sh"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE_PATH="$SYSTEMD_USER_DIR/skills-sync.service"
TIMER_PATH="$SYSTEMD_USER_DIR/skills-sync.timer"
BASH_BIN="$(command -v bash)"

if ! command -v systemctl >/dev/null 2>&1; then
  printf 'systemctl was not found; install a scheduler manually for %s\n' "$SYNC_SCRIPT" >&2
  exit 1
fi

mkdir -p "$SYSTEMD_USER_DIR"
chmod 0755 "$SYNC_SCRIPT"

systemd_env=()
for name in GITHUB_TOKEN GH_TOKEN SSH_AUTH_SOCK; do
  if [[ -n "${!name:-}" ]]; then
    systemd_env+=("$name")
  fi
done

if (( ${#systemd_env[@]} > 0 )); then
  systemctl --user import-environment "${systemd_env[@]}" || true
fi

service_tmp="$(mktemp)"
timer_tmp="$(mktemp)"
trap 'rm -f "$service_tmp" "$timer_tmp"' EXIT

cat >"$service_tmp" <<UNIT
[Unit]
Description=Sync CLI skills from $REPO_DIR

[Service]
Type=oneshot
WorkingDirectory=$REPO_DIR
Environment=GIT_TERMINAL_PROMPT=0
ExecStart=$BASH_BIN $SYNC_SCRIPT
UNIT

cat >"$timer_tmp" <<UNIT
[Unit]
Description=Sync CLI skills every 2 minutes

[Timer]
OnBootSec=30s
OnUnitActiveSec=2min
AccuracySec=15s
Persistent=true
Unit=skills-sync.service

[Install]
WantedBy=timers.target
UNIT

install -m 0644 "$service_tmp" "$SERVICE_PATH"
install -m 0644 "$timer_tmp" "$TIMER_PATH"

systemctl --user daemon-reload
systemctl --user enable --now skills-sync.timer
systemctl --user start skills-sync.service

systemctl --user --no-pager list-timers --all skills-sync.timer
