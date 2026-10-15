#!/usr/bin/env bash
# Install skills from this repo into ~/.claude/skills on a machine without
# the sync loop, such as a Claude Code cloud session. A repo runs it from a
# SessionStart hook (docs/install.md):
#
#   curl -fsSL https://raw.githubusercontent.com/T0mSIlver/skills/main/scripts/install-skills.sh | bash > /dev/null
#
# Usage: install-skills.sh [--from DIR] [--dest DIR] [SKILL...]
#   SKILL...    skills to install; default: the owner workflow and the
#               skills it relies on (DEFAULT_SKILLS below)
#   --from DIR  a checkout to copy from, instead of downloading SKILLS_REF
#               (default main) from GitHub
#   --dest DIR  where to install (default ~/.claude/skills)
#
# A skill directory this script didn't write is left alone, so a machine
# whose sync loop or owner installed it keeps that copy and its local edits.
# It never fails the session: problems are reported and it exits 0.
set -uo pipefail

DEFAULT_SKILLS=(owner-charter intent-card blast-radius verify correct
  debt-review cross-review starbridge unslop unnarrate docs-review test-audit)
MARKER=.installed-by-install-skills
REPO_URL="https://codeload.github.com/T0mSIlver/skills/tar.gz/${SKILLS_REF:-main}"

from=""
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
skills=()
while [ $# -gt 0 ]; do
  case $1 in
    --from) from=$2; shift ;;
    --dest) dest=$2; shift ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) skills+=("$1") ;;
  esac
  shift
done
[ ${#skills[@]} -gt 0 ] || skills=("${DEFAULT_SKILLS[@]}")

warn() { echo "install-skills: $*" >&2; }
ours_or_missing() { [ ! -e "$dest/$1" ] || [ -f "$dest/$1/$MARKER" ]; }

# Nothing to do on a machine that has them all from elsewhere: skip the
# download.
todo=0
for s in "${skills[@]}"; do ours_or_missing "$s" && todo=1; done
[ "$todo" = 1 ] || exit 0

if [ -z "$from" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  if ! curl -fsSL --max-time 60 "$REPO_URL" | tar -xz -C "$tmp" --strip-components=1; then
    warn "could not download $REPO_URL; no skills installed"
    exit 0
  fi
  from=$tmp
fi

mkdir -p "$dest" || { warn "cannot create $dest"; exit 0; }
for s in "${skills[@]}"; do
  if [ ! -f "$from/$s/SKILL.md" ]; then
    warn "skip $s: no such skill"
    continue
  fi
  if ! ours_or_missing "$s"; then
    echo "keep $s: already installed by something else"
    continue
  fi
  rm -rf "${dest:?}/$s.new"
  if cp -R "$from/$s" "$dest/$s.new" && touch "$dest/$s.new/$MARKER" \
    && rm -rf "${dest:?}/$s" && mv "$dest/$s.new" "$dest/$s"; then
    echo "installed $s"
  else
    warn "failed to install $s"
  fi
done
exit 0
