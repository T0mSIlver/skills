#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-main}"
LOCK_FILE="${LOCK_FILE:-${XDG_RUNTIME_DIR:-/tmp}/skills-sync.lock}"
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
# to the installed copy between syncs so the skill can be held (local edits
# win) instead of overwritten. Covers exactly the git-visible state — file
# contents, paths and entry types, symlink targets, and the user exec bit —
# because held edits reconverge through a PR, and anything git cannot record
# (full mode bits, timestamps) could never round-trip: tar-extracted installs
# and git checkouts legitimately disagree on modes (755 vs 775 dirs), which
# would otherwise block reconvergence forever.
STATE_FORMAT="v3"
tree_hash() {
  local dir="$1"
  (
    cd "$dir" && {
      find . -mindepth 1 -printf '%y %p %l\n' | sort
      find . -type f -perm -u+x -printf 'x %p\n' | sort
      find . -type f -print0 | sort -z | xargs -0 -r sha256sum
    }
  ) | sha256sum | cut -d' ' -f1
}

write_dest_readme() {
  local dest_root="$1" held_list="$2"
  cat >"$dest_root/README.md" <<EOF
# Managed directory — synced from the skills repo

Every skill directory in here is synced from $ORIGIN_URL
($REMOTE/$BRANCH) by the \`skills-sync\` systemd user timer, every few
minutes.

Edited a skill here after finding a mistake? That is fine — the sync
detects local edits and HOLDS that skill: your version stays in place
and is not overwritten. Then:

1. Open a PR carrying your edits (\`--dry-run\` to preview):

       skills-pr -m "<skill>: <what you fixed>"

2. Tell the repo owner to review and merge that PR. Once it merges
   as-is, the sync reconverges automatically and resumes managing the
   skill. If the owner merges it with modifications (or upstream
   otherwise changes the skill while held), the upstream version wins
   and replaces the local edits automatically. To throw the local
   edits away yourself:

       skills-pr --discard <skill>

Currently held (local edits present): ${held_list:-none}

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

  if [[ -f "$manifest" ]]; then
    while IFS= read -r old_skill; do
      [[ -n "$old_skill" ]] || continue
      if ! grep -Fxq -- "$old_skill" "$current_manifest"; then
        rm -rf -- "$dest_root/$old_skill"
        log "removed stale synced skill $old_skill from $dest_root"
      fi
    done <"$manifest"
  fi

  # Hashes and hold flags recorded by the previous sync. An installed tree
  # that no longer matches its recorded hash was edited in place; local
  # edits WIN — the skill is held (never overwritten) until the edits reach
  # $REMOTE/$BRANCH (reconverges automatically) or are discarded with
  # 'skills-pr --discard'. A state file from an older hash format is ignored
  # (bootstrap semantics) rather than holding or warning on every skill.
  declare -A last_hash=() last_flag=() hold_base=()
  if [[ -f "$state_file" && "$(head -n1 "$state_file")" == "$STATE_FORMAT" ]]; then
    while read -r name hash flag base; do
      [[ -n "$name" && -n "$hash" ]] || continue
      last_hash["$name"]="$hash"
      last_flag["$name"]="${flag:-synced}"
      hold_base["$name"]="$base"
    done < <(tail -n +2 "$state_file")
  fi

  new_state="$(mktemp)"
  printf '%s\n' "$STATE_FORMAT" >>"$new_state"
  held_skills=""
  for skill_dir in "${skill_dirs[@]}"; do
    skill_name="$(basename "$skill_dir")"
    dest_dir="$dest_root/$skill_name"

    if [[ -d "$dest_dir" && -n "${last_hash[$skill_name]:-}" ]]; then
      installed_hash="$(tree_hash "$dest_dir")"
      if [[ "$installed_hash" != "${last_hash[$skill_name]}" ]]; then
        # Local edits. Installed copies are rsync -a copies of the source,
        # so equal tree hashes mean the edits are now on $REMOTE/$BRANCH.
        src_hash="$(tree_hash "$skill_dir")"
        base="${hold_base[$skill_name]:-}"
        if [[ "$installed_hash" == "$src_hash" ]]; then
          log "local edits to $skill_name are now on $REMOTE/$BRANCH; resuming sync in $dest_root"
          rsync -a --delete -- "$skill_dir/" "$dest_dir/"
          printf '%s %s synced\n' "$skill_name" "$installed_hash" >>"$new_state"
        elif [[ -n "$base" && "$src_hash" != "$base" ]]; then
          # Upstream changed the skill while it was held — the reviewed,
          # merged version is the owner's verdict, so upstream wins. Keep a
          # one-shot copy of the replaced local edits in case no PR carried
          # them.
          replaced="$(mktemp -d -t skills-sync-replaced-XXXXXX)/$skill_name"
          mkdir -p "$replaced"
          rsync -a -- "$dest_dir/" "$replaced/"
          rsync -a --delete -- "$skill_dir/" "$dest_dir/"
          log "NOTICE: $REMOTE/$BRANCH changed $skill_name while it was held (PR merged with modifications?); adopted the upstream version in $dest_dir. The replaced local edits are at $replaced if they were never PR'd."
          printf '%s %s synced\n' "$skill_name" "$(tree_hash "$dest_dir")" >>"$new_state"
        else
          if [[ "${last_flag[$skill_name]:-synced}" != "held" ]]; then
            log "NOTICE: local edits in $dest_dir — leaving them in place (sync held for this skill). Open a PR with: skills-pr -m '$skill_name: <what you fixed>' — then ask the repo owner to review and merge it. Discard the local edits instead with: skills-pr --discard $skill_name"
          fi
          held_skills="${held_skills:+$held_skills, }$skill_name"
          # The hold baseline is the last-synced state (the fork point):
          # installed == source whenever a skill is in sync, so last_hash is
          # the source hash the local edits were made against. An upstream
          # change landing in the same window as the local edit then still
          # triggers adoption on the next run.
          printf '%s %s held %s\n' "$skill_name" "${last_hash[$skill_name]}" "${base:-${last_hash[$skill_name]}}" >>"$new_state"
        fi
        continue
      fi
    fi

    changes="$(rsync -ai --delete -- "$skill_dir/" "$dest_dir/")"
    if [[ -n "$changes" ]]; then
      log "synced $skill_name to $dest_root (content updated)"
    fi
    printf '%s %s synced\n' "$skill_name" "$(tree_hash "$dest_dir")" >>"$new_state"
  done
  install -m 0644 "$new_state" "$state_file"
  rm -f "$new_state"

  write_dest_readme "$dest_root" "$held_skills"
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
