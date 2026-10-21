#!/usr/bin/env bash
# Install skills from this repo into ~/.claude/skills on a machine without
# the sync loop, such as a Claude Code cloud session. A repo runs it from a
# SessionStart hook (docs/install.md):
#
#   curl -fsSL https://raw.githubusercontent.com/T0mSIlver/skills/main/scripts/install-skills.sh | bash > /dev/null
#
# Usage: install-skills.sh [--dest DIR] [SKILL...]
#        install-skills.sh --print-list
#   SKILL...      skills to install; default: the owner workflow and the
#                 skills it relies on (DEFAULT_SKILLS below)
#   --dest DIR    where to install (default ~/.claude/skills)
#   --print-list  print the file list this script downloads from, generated
#                 from a checkout; tests/install-skills.sh fails when the
#                 committed scripts/install-skills.list differs
#
# Files come one by one from raw.githubusercontent.com (SKILLS_BASE_URL),
# following scripts/install-skills.list: a cloud session's GitHub proxy
# refuses codeload archives of repos not attached to the session.
#
# A skill directory this script didn't write is left alone, so a machine
# whose sync loop or owner installed it keeps that copy and its local edits.
# It never fails the session: problems are reported and it exits 0.
set -uo pipefail

DEFAULT_SKILLS=(owner-charter intent-card blast-radius verify correct
  debt-review cross-review starbridge unslop unnarrate docs-review one-term test-audit)
MARKER=.installed-by-install-skills
BASE_URL="${SKILLS_BASE_URL:-https://raw.githubusercontent.com/T0mSIlver/skills/${SKILLS_REF:-main}}"

warn() { echo "install-skills: $*" >&2; }

# Every file git would track (untracked ones too, so a vendoring run sees
# new upstream files) of every top-level directory holding a SKILL.md.
print_list() {
  local root
  root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P) || return 1
  git -C "$root" ls-files --cached --others --exclude-standard | LC_ALL=C sort -u \
    | awk -F/ 'NF > 1' | while IFS= read -r f; do
    if [ -f "$root/${f%%/*}/SKILL.md" ]; then printf '%s\n' "$f"; fi
  done
}

dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
skills=()
while [ $# -gt 0 ]; do
  case $1 in
    --print-list) print_list; exit $? ;;
    --dest)
      if [ $# -lt 2 ]; then warn "--dest needs a directory"; exit 0; fi
      dest=$2; shift ;;
    -h|--help) awk 'NR > 1 && /^#/ { print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) skills+=("$1") ;;
  esac
  shift
done
[ ${#skills[@]} -gt 0 ] || skills=("${DEFAULT_SKILLS[@]}")

# Downloads lose the executable bit; give it back to every script.
mark_scripts_executable() {
  local f
  while IFS= read -r -d '' f; do
    [ "$(head -c 2 "$f")" = '#!' ] && chmod +x "$f"
  done < <(find "$1" -type f -print0)
  return 0
}
ours_or_missing() { [ ! -e "$dest/$1" ] || [ -f "$dest/$1/$MARKER" ]; }

# Every skill came from elsewhere (the sync loop): skip the download. Its
# own copies are refreshed on every run.
todo=0
for s in "${skills[@]}"; do ours_or_missing "$s" && todo=1; done
[ "$todo" = 1 ] || exit 0

if ! list=$(curl -fsSL --max-time 30 "$BASE_URL/scripts/install-skills.list"); then
  warn "could not download $BASE_URL/scripts/install-skills.list; no skills installed"
  exit 0
fi

mkdir -p "$dest" || { warn "cannot create $dest"; exit 0; }
for s in "${skills[@]}"; do
  files=$(printf '%s\n' "$list" | grep "^$s/") || true
  if ! printf '%s\n' "$files" | grep -qx "$s/SKILL.md"; then
    warn "skip $s: no such skill"
    continue
  fi
  if ! ours_or_missing "$s"; then
    echo "keep $s: already installed by something else"
    continue
  fi
  new="$dest/$s.new"
  rm -rf "${new:?}"
  args=()
  while IFS= read -r f; do
    args+=(-o "$new/${f#"$s"/}" "$BASE_URL/$f")
  done <<<"$files"
  if curl -fsSL --fail-early --max-time 60 --create-dirs "${args[@]}" \
    && mark_scripts_executable "$new" && touch "$new/$MARKER" \
    && rm -rf "${dest:?}/$s" && mv "$new" "$dest/$s"; then
    echo "installed $s"
  else
    rm -rf "${new:?}"
    warn "failed to install $s"
  fi
done
exit 0
