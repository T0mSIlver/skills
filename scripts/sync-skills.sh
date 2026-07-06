#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-main}"
LOCK_FILE="${LOCK_FILE:-${XDG_RUNTIME_DIR:-/tmp}/skills-sync.lock}"
BACKUP_KEEP="${BACKUP_KEEP:-10}"
export GIT_TERMINAL_PROMPT="${GIT_TERMINAL_PROMPT:-0}"
SYNC_SOURCE="$REPO_DIR"
SYNC_COMMIT=""
ARCHIVE_DIR=""
current_manifest=""

DESTINATIONS=(
  "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  "${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
  "${OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}"
)

HELPER_SPECS=(
  "delegate-to-claude-code/scripts/claude-rc-spawn:claude-rc-spawn"
  "claude-remote-control-server/scripts/install-claude-rc-server-service.sh:install-claude-rc-server-service.sh"
  "scripts/skills-pr:skills-pr"
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
    SYNC_COMMIT="$(git rev-parse --short FETCH_HEAD 2>/dev/null || true)"
    log "using fetched $REMOTE/$BRANCH"
  else
    log "git archive failed; continuing with local checkout"
  fi
else
  log "git fetch failed; continuing with local checkout"
fi
if [[ -z "$SYNC_COMMIT" ]]; then
  SYNC_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)-local"
fi
# Strip userinfo (user:token@) from the remote URL before it lands in the
# generated READMEs — HTTPS remotes can embed a PAT.
ORIGIN_URL="$(git remote get-url "$REMOTE" 2>/dev/null | sed -E 's#^([a-z+]+://)[^@/]+@#\1#' || true)"
ORIGIN_URL="${ORIGIN_URL:-$REPO_DIR}"

# Content+structure hash of a synced skill directory: detects local edits made
# to the installed copy between syncs so they can be preserved instead of
# silently destroyed by rsync --delete. Covers what rsync -a manages: file
# contents, entry types, permissions, and symlink targets (not timestamps).
STATE_FORMAT="v2"
tree_hash() {
  local dir="$1"
  (
    cd "$dir" && {
      find . -mindepth 1 -printf '%y %m %p %l\n' | sort
      find . -type f -print0 | sort -z | xargs -0 -r sha256sum
    }
  ) | sha256sum | cut -d' ' -f1
}

write_dest_readme() {
  local dest_root="$1"
  cat >"$dest_root/README.md" <<EOF
# Managed directory — synced from the skills repo

Every skill directory in here is synced from $ORIGIN_URL
($REMOTE/$BRANCH) by the \`skills-sync\` systemd user timer, every few
minutes. Direct edits never persist: the next sync reverts them (a
pre-sync copy is kept under \`.skills-sync-backups/\`, the $BACKUP_KEEP
most recent, with a WARNING in
\`journalctl --user -u skills-sync.service\`).

Found a mistake in a skill while using it? Fix it here in place, then
immediately run:

    skills-pr -m "<skill>: <what you fixed>"

It diffs the installed copies against the repo and opens a PR carrying
your edits (\`--dry-run\` to preview). If the sync reverted your edit
before you ran it, recover it from the backup:

    skills-pr --from-backup <skill> -m "..."

Skills not managed by the repo are left alone.

Last sync: $(date -Is) from commit $SYNC_COMMIT
EOF
}

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
  state_file="$dest_root/.skills-sync-state"
  backup_root="$dest_root/.skills-sync-backups"

  if [[ -f "$manifest" ]]; then
    while IFS= read -r old_skill; do
      [[ -n "$old_skill" ]] || continue
      if ! grep -Fxq -- "$old_skill" "$current_manifest"; then
        rm -rf -- "$dest_root/$old_skill"
        log "removed stale synced skill $old_skill from $dest_root"
      fi
    done <"$manifest"
  fi

  # Hashes recorded by the previous sync; a mismatch against the current
  # installed tree means someone edited the installed copy since then. A
  # state file from an older hash format is ignored (bootstrap semantics)
  # rather than producing a spurious warning for every skill.
  declare -A last_hash=()
  if [[ -f "$state_file" && "$(head -n1 "$state_file")" == "$STATE_FORMAT" ]]; then
    while read -r name hash; do
      [[ -n "$name" && -n "$hash" ]] && last_hash["$name"]="$hash"
    done < <(tail -n +2 "$state_file")
  fi

  new_state="$(mktemp)"
  printf '%s\n' "$STATE_FORMAT" >>"$new_state"
  for skill_dir in "${skill_dirs[@]}"; do
    skill_name="$(basename "$skill_dir")"
    dest_dir="$dest_root/$skill_name"

    if [[ -d "$dest_dir" && -n "${last_hash[$skill_name]:-}" ]] \
      && [[ "$(tree_hash "$dest_dir")" != "${last_hash[$skill_name]}" ]]; then
      backup_dir="$backup_root/$(date +%Y%m%dT%H%M%S)-$skill_name"
      mkdir -p "$backup_dir"
      rsync -a -- "$dest_dir/" "$backup_dir/"
      log "WARNING: local edits detected in $dest_dir — installed copies are always overwritten; pre-sync copy preserved at $backup_dir; run 'skills-pr --from-backup $skill_name' to open a PR with them"
    fi

    changes="$(rsync -ai --delete -- "$skill_dir/" "$dest_dir/")"
    if [[ -n "$changes" ]]; then
      log "synced $skill_name to $dest_root (content updated)"
    fi
    printf '%s %s\n' "$skill_name" "$(tree_hash "$dest_dir")" >>"$new_state"
  done
  install -m 0644 "$new_state" "$state_file"
  rm -f "$new_state"

  if [[ -d "$backup_root" ]]; then
    mapfile -t stale_backups < <(ls -1t -- "$backup_root" | tail -n +$((BACKUP_KEEP + 1)))
    for stale in "${stale_backups[@]}"; do
      [[ -n "$stale" ]] && rm -rf -- "$backup_root/$stale"
    done
  fi

  write_dest_readme "$dest_root"
  # Breadcrumb for skills-pr: where the repo checkout lives.
  printf '%s\n' "$REPO_DIR" >"$dest_root/.skills-sync-repo"
  install -m 0644 "$current_manifest" "$manifest"
done

bin_dir="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$bin_dir"
for helper_spec in "${HELPER_SPECS[@]}"; do
  helper_source="${helper_spec%%:*}"
  helper_name="${helper_spec##*:}"
  helper_path="$SYNC_SOURCE/$helper_source"
  if [[ -f "$helper_path" ]]; then
    install -m 0755 "$helper_path" "$bin_dir/$helper_name"
    log "installed $helper_name to $bin_dir"
  else
    log "helper $helper_name was not found at $helper_source"
  fi
done
