#!/usr/bin/env bash
# cross-review --proof PR grades a PR's proof and posts one marked comment. A stub
# codex stands in for the reviewer and a stub gh for GitHub.
set -euo pipefail

script=$(readlink -f "$(dirname "$0")/../cross-review/scripts/cross-review")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir "$tmp/bin"
cat > "$tmp/bin/codex" <<'SH'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do case $1 in -o) out=$2 ;; esac; shift; done
cat "$STUB_ANSWER" > "$out"
echo '{"type": "thread.started", "thread_id": "stub"}'
SH
cat > "$tmp/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  "pr view "*"headRefOid,baseRefName,title,body"*) cat "$GH_PR_JSON" ;;
  "pr view "*"--jq .headRefOid"*) jq -r .headRefOid "$GH_PR_JSON" ;;
  "repo view"*) echo o/r ;;
  "issue view"*) printf 'Issue title\n\nissue text\n' ;;
  "api user"*) echo me ;;
  "api --paginate"*) cat "$GH_EXISTING" 2>/dev/null || true ;;
  *)
    for a in "$@"; do case $a in body=@*) cp "${a#body=@}" "$GH_BODY" ;; esac; done
    case "$1 $2" in "api -X") echo PATCH > "$GH_VERB" ;; *) echo POST > "$GH_VERB" ;; esac ;;
esac
SH
for r in opencode vibe; do printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/$r"; done
printf '#!/bin/sh\necho "zai 5h 99%%"\n' > "$tmp/bin/quota"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" GH_PR_JSON="$tmp/pr.json" GH_EXISTING="$tmp/existing" \
  GH_BODY="$tmp/body" GH_VERB="$tmp/verb" STUB_ANSWER="$tmp/answer"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

git init -q --bare -b main "$tmp/origin.git"
repo=$tmp/repo
git clone -q "$tmp/origin.git" "$repo" 2>/dev/null
git -C "$repo" switch -q -c main
cat > "$repo/CONTRIBUTING.md" <<'MD'
# Contributing

## What merges without the owner

Merge by default: bug fixes, tests.
Sign-off: features.

## Develop
MD
git -C "$repo" add CONTRIBUTING.md
git -C "$repo" commit -q -m base
git -C "$repo" push -q origin main
git -C "$repo" switch -q -c feature
echo change > "$repo/f"
git -C "$repo" add f
git -C "$repo" commit -q -m change
head=$(git -C "$repo" rev-parse HEAD)
runs=$tmp/runs

pr() { jq -n --arg h "$1" '{headRefOid: $h, baseRefName: "main", title: "Fix f", body: "Closes #7\n\n## Blast radius\nnone"}' > "$tmp/pr.json"; }
answer() { # verdict class [findings-json]
  jq -n --arg v "$1" --arg c "$2" --argjson f "${3:-[]}" \
    '{findings: $f, overall_explanation: "stub", proof: {verdict: $v, class: $c, reasons: ["because"]}}' > "$tmp/answer"
}
xr() { rm -f "$tmp/body" "$tmp/verb"; rc=0
  out=$(cd "$repo" && CROSS_REVIEW_DIR=$runs "$script" --proof 12 --vendor codex 2>&1) || rc=$?; }

# A sufficient, merge-by-default PR: one new comment, marked, naming the head.
pr "$head"; answer "PROOF SUFFICIENT" merge-by-default
xr
[ "$rc" = 0 ] || fail "exit $rc: $out"
[ "$(cat "$tmp/verb")" = POST ] || fail "no new comment"
[ "$(head -1 "$tmp/body")" = "<!-- proof-verdict -->" ] || fail "marker not first line"
grep -qx -- "- Head: $head" "$tmp/body" || fail "head sha missing"
grep -qx -- "- Verdict: PROOF SUFFICIENT" "$tmp/body" || fail "verdict missing"
grep -qx -- "- Class: merge-by-default" "$tmp/body" || fail "class missing"
grep -q -- "- Reviewer: codex (" "$tmp/body" || fail "reviewer missing"

# An existing comment of mine is edited, not duplicated.
echo 99 > "$tmp/existing"
xr
[ "$(cat "$tmp/verb")" = PATCH ] || fail "existing comment not edited"
rm -f "$tmp/existing"

# An open P1 finding downgrades the grade.
answer "PROOF SUFFICIENT" merge-by-default '[{"title":"bad","body":"b","priority":1,"confidence":0.9,"file":"f","line_start":1,"line_end":1}]'
xr
grep -qx -- "- Verdict: PROOF INSUFFICIENT" "$tmp/body" || fail "P1 did not downgrade: $(cat "$tmp/body")"
grep -q "open P1 finding f:1" "$tmp/body" || fail "P1 not in reasons"

# Under .github/ or deploy/, the class is sign-off whatever the reviewer says.
git -C "$repo" switch -q -c ci
mkdir "$repo/.github"; echo x > "$repo/.github/w.yml"
git -C "$repo" add .github; git -C "$repo" commit -q -m ci
pr "$(git -C "$repo" rev-parse HEAD)"; answer "PROOF SUFFICIENT" merge-by-default
xr
grep -qx -- "- Class: sign-off" "$tmp/body" || fail "workflow change kept merge-by-default"

# A PR that edits the class list is sign-off.
git -C "$repo" switch -q feature; git -C "$repo" switch -q -c policy
sed -i 's/bug fixes, tests/everything/' "$repo/CONTRIBUTING.md"
git -C "$repo" commit -q -am policy
pr "$(git -C "$repo" rev-parse HEAD)"
xr
grep -qx -- "- Class: sign-off" "$tmp/body" || fail "list edit kept merge-by-default"

# A PR head that is not HEAD is refused before any review.
pr "$head"
xr
[ "$rc" = 1 ] && [[ $out == *"not PR #12's pushed head"* ]] || fail "stale HEAD accepted: $rc $out"
[ ! -e "$tmp/verb" ] || fail "posted for a stale head"

# An invalid proof object is sent back, then fails the run.
git -C "$repo" switch -q feature
echo '{"findings":[],"overall_explanation":"x"}' > "$tmp/answer"
xr
[ "$rc" = 2 ] || fail "missing proof accepted: $rc $out"

echo "cross-review proof tests passed"
