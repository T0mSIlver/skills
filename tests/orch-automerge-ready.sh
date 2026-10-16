#!/usr/bin/env bash
# orch-automerge-ready prints READY only when every condition holds. Stub gh,
# starbridge and orch-mergecheck stand in for the world.
set -euo pipefail

src=$(readlink -f "$(dirname "$0")/../orchestrate-sessions/scripts")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir "$tmp/bin"
cp "$src/orch-automerge-ready" "$src/orch-lib.sh" "$tmp/bin/"
printf '#!/bin/sh\n[ -z "$MC_FAIL" ] || { echo "$MC_FAIL"; exit 5; }\necho OK\n' > "$tmp/bin/orch-mergecheck"
cat > "$tmp/bin/gh" <<'SH'
#!/usr/bin/env bash
# gh api [--paginate] PATH [--jq FILTER]: serve fixtures, apply the filter with jq.
path="" jq=""
while [ $# -gt 0 ]; do case $1 in api|--paginate) ;; --jq) jq=$2; shift ;; *) path=$1 ;; esac; shift; done
case $path in
  */pulls/*/files) f=files.json ;;
  */pulls/*) f=pr.json ;;
  */check-runs*) f=checks.json ;;
  */status) f=status.json ;;
  */comments) f=comments.json ;;
esac
if [ -n "$jq" ]; then jq -r "$jq" "$GH_DIR/$f"; else cat "$GH_DIR/$f"; fi
SH
printf '#!/bin/sh\ncat "$GH_DIR/cards" 2>/dev/null || exit 1\n' > "$tmp/bin/starbridge"
chmod +x "$tmp/bin/"*
export GH_DIR=$tmp/fx MC_FAIL="" PATH="$tmp/bin:$PATH"
mkdir "$GH_DIR"
cat > "$tmp/o.env" <<'E'
REPO=owner/repo
GATE_CHECKS="test"
COMBO_CHECKS="test"
E
export ORCH_CONFIG=$tmp/o.env
sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

reset() {
  echo "{\"state\":\"open\",\"draft\":false,\"head\":{\"sha\":\"$sha\"}}" > "$GH_DIR/pr.json"
  echo '[{"filename":"src/a.ts"}]' > "$GH_DIR/files.json"
  echo '{"check_runs":[{"name":"test","status":"completed","conclusion":"success","id":1},{"name":"lint","status":"completed","conclusion":"skipped","id":2}]}' > "$GH_DIR/checks.json"
  echo '{"total_count":0,"state":"pending"}' > "$GH_DIR/status.json"
  comment owner "$sha" "PROOF SUFFICIENT" merge-by-default
  echo '{"decisionId":"d_x","question":"Unrelated PR #99?"}' > "$GH_DIR/cards"
  MC_FAIL=""
}
comment() { # author head verdict class
  jq -n --arg u "$1" --arg b "<!-- proof-verdict -->
## Proof verdict: $3

- Head: $2
- Verdict: $3
- Class: $4" '[{user:{login:$u}, body:$b}]' > "$GH_DIR/comments.json"
}
# gh's --jq runs on the array and emits one object per line; the stub's jq -r does the same.
run() { rc=0; out=$("$tmp/bin/orch-automerge-ready" 12 2>&1) || rc=$?; }
expect() { # substring of the NOT READY line, or READY
  run
  if [ "$1" = READY ]; then [ "$rc" = 0 ] && [[ $out == "READY #12"* ]] || fail "$2: $rc $out"
  else [ "$rc" = 1 ] && [[ $out == *"$1"* ]] || fail "$2: $rc $out"; fi
}

reset; expect READY "all conditions hold"
reset; echo '[{"filename":".github/workflows/ci.yml"}]' > "$GH_DIR/files.json"; expect ".github/" "workflow file"
reset; echo '[{"filename":"x","previous_filename":"deploy/a.sh"}]' > "$GH_DIR/files.json"; expect "deploy/" "rename out of deploy/"
reset; sed -i 's/"conclusion":"success"/"conclusion":"failure"/' "$GH_DIR/checks.json"; expect "checks not green: test=failure" "red check"
reset; sed -i 's/"conclusion":"success"/"conclusion":null/;s/"completed"/"in_progress"/' "$GH_DIR/checks.json"; expect "test=in_progress" "running check"
reset; echo '{"check_runs":[]}' > "$GH_DIR/checks.json"; expect "no CI checks" "no checks"
reset; echo '{"total_count":1,"state":"failure"}' > "$GH_DIR/status.json"; expect "commit status is failure" "red status"
reset; comment owner bbbbbbbb "PROOF SUFFICIENT" merge-by-default; expect "stale" "stale SHA"
reset; comment owner "$sha" "PROOF INSUFFICIENT" merge-by-default; expect "PROOF INSUFFICIENT" "insufficient"
reset; comment owner "$sha" "PROOF SUFFICIENT" sign-off; expect "not merge-by-default" "sign-off class"
reset; comment stranger "$sha" "PROOF SUFFICIENT" merge-by-default; expect "no proof-verdict comment" "comment by a stranger"
reset; echo '[]' > "$GH_DIR/comments.json"; expect "no proof-verdict comment" "no comment"
reset; echo '{"question":"Merge PR #12?"}' > "$GH_DIR/cards"; expect "open card" "card names PR"
reset; echo '{"question":"see https://github.com/o/r/pull/12"}' > "$GH_DIR/cards"; expect "open card" "card names pull url"
reset; echo '{"question":"PR #123?"}' > "$GH_DIR/cards"; expect READY "card for #123 is not #12"
reset; rm "$GH_DIR/cards"; expect "cannot read open cards" "starbridge down"
reset; MC_FAIL="CONFLICT with main"; expect "orch-mergecheck: CONFLICT" "mergecheck refuses"
reset; sed -i 's/"draft":false/"draft":true/' "$GH_DIR/pr.json"; expect "draft" "draft"
reset; echo '[{"filename":".github/a"}]' > "$GH_DIR/files.json"; comment owner "$sha" "PROOF INSUFFICIENT" sign-off
expect ".github/" "reasons are collected"; [[ $out == *";"* ]] || fail "only one reason: $out"

echo "orch-automerge-ready tests passed"
