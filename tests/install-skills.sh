#!/usr/bin/env bash
# install-skills.sh never overwrites a skill it didn't install, because on a
# machine with the sync loop that copy may hold local edits.
set -euo pipefail

script=$(readlink -f "$(dirname "$0")/../scripts/install-skills.sh")
repo=$(readlink -f "$(dirname "$0")/..")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$tmp/dest/unslop"
echo "local edit" > "$tmp/dest/unslop/SKILL.md"

"$script" --from "$repo" --dest "$tmp/dest" unslop unnarrate no-such-skill > "$tmp/out" 2>&1
grep -qx "keep unslop: already installed by something else" "$tmp/out" || fail "unslop not kept: $(cat "$tmp/out")"
[ "$(cat "$tmp/dest/unslop/SKILL.md")" = "local edit" ] || fail "overwrote a skill it didn't install"
cmp -s "$repo/unnarrate/SKILL.md" "$tmp/dest/unnarrate/SKILL.md" || fail "unnarrate not installed"

# Its own copy is replaced on the next run.
echo stale > "$tmp/dest/unnarrate/SKILL.md"
"$script" --from "$repo" --dest "$tmp/dest" unnarrate > /dev/null 2>&1
cmp -s "$repo/unnarrate/SKILL.md" "$tmp/dest/unnarrate/SKILL.md" || fail "own copy not refreshed"
echo "install-skills: ok"
