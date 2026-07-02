#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-main}"
LOCK_FILE="${LOCK_FILE:-${XDG_RUNTIME_DIR:-/tmp}/skills-sync.lock}"
export GIT_TERMINAL_PROMPT="${GIT_TERMINAL_PROMPT:-0}"
SYNC_SOURCE="$REPO_DIR"
ARCHIVE_DIR=""
current_manifest=""

DESTINATIONS=(
  "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  "${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
  "${OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}"
)

log() {
  printf '[%s] %s\n' "$(date -Is)" "$*"
}

has() {
  command -v "$1" >/dev/null 2>&1
}

cleanup() {
  [[ -n "${ARCHIVE_DIR:-}" ]] && rm -rf "$ARCHIVE_DIR"
  [[ -n "${current_manifest:-}" ]] && rm -f "$current_manifest"
}
trap cleanup EXIT

if has flock; then
  mkdir -p "$(dirname "$LOCK_FILE")"
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    log "another sync is already running"
    exit 0
  fi
fi

cd "$REPO_DIR"

if ! has git; then
  log "git is required but was not found"
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  log "not a git repository: $REPO_DIR"
  exit 1
fi

if ! has rsync; then
  log "rsync is required but was not found"
  exit 1
fi

if ! has tar; then
  log "tar is required but was not found"
  exit 1
fi

if git fetch --prune "$REMOTE" "$BRANCH"; then
  ARCHIVE_DIR="$(mktemp -d)"
  if git archive FETCH_HEAD | tar -x -C "$ARCHIVE_DIR"; then
    SYNC_SOURCE="$ARCHIVE_DIR"
    log "using fetched $REMOTE/$BRANCH"
  else
    log "git archive failed; continuing with local checkout"
  fi
else
  log "git fetch failed; continuing with local checkout"
fi

mapfile -d '' skill_dirs < <(
  find "$SYNC_SOURCE" \
    -mindepth 2 \
    -maxdepth 2 \
    -type f \
    -name SKILL.md \
    -not -path '*/.git/*' \
    -printf '%h\0' |
    sort -z
)

if (( ${#skill_dirs[@]} == 0 )); then
  log "no skill directories found under $REPO_DIR"
  exit 1
fi

current_manifest="$(mktemp)"

for skill_dir in "${skill_dirs[@]}"; do
  basename "$skill_dir"
done >"$current_manifest"

for dest_root in "${DESTINATIONS[@]}"; do
  mkdir -p "$dest_root"
  manifest="$dest_root/.skills-sync-manifest"

  if [[ -f "$manifest" ]]; then
    while IFS= read -r old_skill; do
      [[ -n "$old_skill" ]] || continue
      if ! grep -Fxq -- "$old_skill" "$current_manifest"; then
        rm -rf -- "$dest_root/$old_skill"
        log "removed stale synced skill $old_skill from $dest_root"
      fi
    done <"$manifest"
  fi

  for skill_dir in "${skill_dirs[@]}"; do
    skill_name="$(basename "$skill_dir")"
    rsync -a --delete -- "$skill_dir/" "$dest_root/$skill_name/"
    log "synced $skill_name to $dest_root"
  done

  install -m 0644 "$current_manifest" "$manifest"
done
