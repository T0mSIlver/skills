#!/usr/bin/env bash
# install-skills.sh downloads every file the committed list names, never
# overwrites a skill it didn't install (on a machine with the sync loop that
# copy may hold local edits), and the list matches the repo.
set -euo pipefail

script=$(readlink -f "$(dirname "$0")/../scripts/install-skills.sh")
repo=$(readlink -f "$(dirname "$0")/..")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

"$script" --print-list | diff -u "$repo/scripts/install-skills.list" - \
  || fail "scripts/install-skills.list is stale: run scripts/install-skills.sh --print-list > scripts/install-skills.list"

export SKILLS_BASE_URL="file://$repo"
mkdir -p "$tmp/dest/unslop"
echo "local edit" > "$tmp/dest/unslop/SKILL.md"

"$script" --dest "$tmp/dest" unslop cross-review no-such-skill > "$tmp/out" 2>&1
grep -qx "keep unslop: already installed by something else" "$tmp/out" || fail "unslop not kept: $(cat "$tmp/out")"
[ "$(cat "$tmp/dest/unslop/SKILL.md")" = "local edit" ] || fail "overwrote a skill it didn't install"
diff -r -x .installed-by-install-skills "$repo/cross-review" "$tmp/dest/cross-review" \
  || fail "cross-review not installed whole"
[ -x "$tmp/dest/cross-review/scripts/cross-review" ] || fail "script lost its executable bit"

# Its own copy is replaced on the next run.
echo stale > "$tmp/dest/cross-review/SKILL.md"
"$script" --dest "$tmp/dest" cross-review > /dev/null 2>&1
cmp -s "$repo/cross-review/SKILL.md" "$tmp/dest/cross-review/SKILL.md" || fail "own copy not refreshed"
echo "install-skills: ok"
