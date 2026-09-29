#!/usr/bin/env bash
# cross-review reuses an earlier review of HEAD only when it came from the
# vendor and model this call would use (#126). A stub codex stands in for the reviewer.
set -euo pipefail

script=$(readlink -f "$(dirname "$0")/../cross-review/scripts/cross-review")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir "$tmp/bin"
cat > "$tmp/bin/codex" <<'SH'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
  case $1 in -o) out=$2 ;; -m) echo "$2" > "$CODEX_RAN.model" ;; esac
  shift
done
echo '{"findings": [], "overall_explanation": "stub codex"}' > "$out"
echo '{"type": "thread.started", "thread_id": "stub"}'
touch "$CODEX_RAN"
SH
# The other reviewers fail, so a test can never reach a real one.
for r in opencode vibe; do printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/$r"; done
printf '#!/bin/sh\necho "zai 5h 0%%"\n' > "$tmp/bin/quota"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" CODEX_RAN="$tmp/codex-ran"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

repo=$tmp/repo
git init -q -b main "$repo"
git -C "$repo" commit -q --allow-empty -m base
git -C "$repo" switch -q -c feature
echo change > "$repo/f"
git -C "$repo" add f
git -C "$repo" commit -q -m change
head=$(git -C "$repo" rev-parse HEAD)
echo "Change f." > "$tmp/brief"

# Runs cross-review in the repo; sets out and rc.
xr() {
  rm -f "$CODEX_RAN"
  rc=0
  out=$(cd "$repo" && CROSS_REVIEW_DIR=$runs "$script" --brief "$tmp/brief" --base main "$@" 2>&1) || rc=$?
}
# A completed GLM run dir: fake_run DIR REVIEWED-LINE
fake_run() {
  mkdir -p "$runs/$1"
  touch "$runs/$1/glm.jsonl"
  echo "$2" > "$runs/$1/reviewed"
  echo "summary of $1" > "$runs/$1/summary.md"
}

# A GLM review of HEAD, recorded before the vendor was, does not count for
# --vendor codex; it still counts for --vendor auto.
runs=$tmp/runs1
fake_run glm-run "$head feature whole"
xr --vendor codex
[ "$rc" = 0 ] || fail "--vendor codex exited $rc: $out"
[ -f "$CODEX_RAN" ] || fail "--vendor codex reused the GLM review: $out"
[[ $out == *"cross-review by codex"* ]] || fail "no codex review in: $out"
runs=$tmp/runs2
fake_run glm-run "$head feature whole"
xr --vendor auto
[[ $out == *"summary of glm-run"* ]] || fail "--vendor auto did not reuse the old review: $out"

# The same with the vendor and model recorded.
runs=$tmp/runs3
fake_run glm-run "$head feature whole glm zai-coding-plan/glm-5.3"
xr --vendor codex
[ -f "$CODEX_RAN" ] || fail "--vendor codex reused the GLM review: $out"
runs=$tmp/runs4
fake_run glm-run "$head feature whole glm zai-coding-plan/glm-5.3"
xr --vendor auto
[[ $out == *"summary of glm-run"* ]] || fail "--vendor auto did not reuse GLM's review: $out"

# A Codex review is recorded as Codex's and reused by the next --vendor codex.
runs=$tmp/runs1
xr --vendor codex
[ ! -f "$CODEX_RAN" ] || fail "second --vendor codex ran codex again"
[[ $out == *"already reviewed"*"stub codex"* ]] || fail "second --vendor codex did not reuse: $out"

# Another Codex model does not reuse it, and its review is recorded as its own.
CROSS_REVIEW_CODEX_MODEL=gpt-6-astra xr --vendor codex
[ -f "$CODEX_RAN" ] || fail "gpt-6-astra reused the default model's review: $out"
[ "$(cat "$CODEX_RAN.model")" = gpt-6-astra ] || fail "codex ran $(cat "$CODEX_RAN.model"), not gpt-6-astra"
CROSS_REVIEW_CODEX_MODEL=gpt-6-astra xr --vendor codex
[ ! -f "$CODEX_RAN" ] || fail "second gpt-6-astra review ran codex again"

# A review recorded with its vendor but not its model counts only for auto.
runs=$tmp/runs5
fake_run codex-run "$head feature whole codex"
xr --vendor codex
[ -f "$CODEX_RAN" ] || fail "--vendor codex reused a review of unknown model: $out"

echo "cross-review vendor tests passed"
