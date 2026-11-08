#!/usr/bin/env bash
# In a T3 Code session cross-review runs no reviewer: it hands off to a
# delegate_task child, and --ingest scores the child's answer.
set -euo pipefail

script=$(readlink -f "$(dirname "$0")/../cross-review/scripts/cross-review")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir "$tmp/bin"
# Any reviewer CLI that runs is a failure.
printf '#!/bin/sh\ntouch "%s/cli-ran"\nexit 1\n' "$tmp" > "$tmp/bin/opencode"
cp "$tmp/bin/opencode" "$tmp/bin/codex"
printf '#!/bin/sh\necho "zai 5h 0%%"\n' > "$tmp/bin/quota"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" CROSS_REVIEW_DIR=$tmp/runs T3CODE_THREAD_ID=test
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

repo=$tmp/repo
git init -q -b main "$repo"
git -C "$repo" commit -q --allow-empty -m base
git -C "$repo" switch -q -c feature
printf 'a\nb\n' > "$repo/f"
git -C "$repo" add f
git -C "$repo" commit -q -m change
echo "Add f." > "$tmp/brief"

rc=0; out=$(cd "$repo" && "$script" --brief "$tmp/brief" --base main 2>&1) || rc=$?
[ "$rc" = 5 ] || fail "handoff exited $rc: $out"
[ ! -e "$tmp/cli-ran" ] || fail "a reviewer CLI ran in a T3 session"
[[ $out == *'model: "zai-coding-plan/glm-5.3"'* ]] || fail "no GLM target in: $out"
run=$(sed -n 's/.*cross-review --ingest //p' <<< "$out")
[ -f "$run/tree/f" ] || fail "the frozen copy is gone after the handoff"
grep -q "$run/prompt.md" "$run/t3-task.md" || fail "the task does not point at the prompt"

rc=0; out=$("$script" --ingest "$run" 2>&1) || rc=$?
[ "$rc" = 2 ] || fail "ingest without an answer exited $rc: $out"
echo '{"findings":[{"title":"x","body":"y","file":"f"}]}' > "$run/answer.json"
rc=0; out=$("$script" --ingest "$run" 2>&1) || rc=$?
[ "$rc" = 2 ] && [[ $out == *priority* ]] || fail "an invalid answer was not refused with its reason: $out"

echo '{"findings":[{"title":"bad b","body":"y","priority":1,"confidence":0.9,"file":"f","line_start":2,"line_end":2}],"overall_explanation":"ok"}' > "$run/answer.json"
rc=0; out=$("$script" --ingest "$run" 2>&1) || rc=$?
[ "$rc" = 0 ] || fail "ingest exited $rc: $out"
[[ $out == *"cross-review by glm"*"patch is incorrect"*"[P1] f:2 bad b"* ]] || fail "wrong summary: $out"
[ ! -e "$run/tree" ] || fail "ingest left the frozen copy"
grep -q " glm zai-coding-plan/glm-5.3$" "$run/reviewed" || fail "the review is not recorded as GLM's"

# The next run reuses it instead of handing off again.
rc=0; out=$(cd "$repo" && "$script" --brief "$tmp/brief" --base main 2>&1) || rc=$?
[ "$rc" = 0 ] && [[ $out == *"already reviewed"* ]] || fail "a reviewed HEAD was handed off again: $out"

# A full GLM week sends the review to Codex.
printf '#!/bin/sh\necho "zai 5h 0%%"\necho "zai week 100%%"\necho "codex 5h 0%%"\necho "codex week 0%%"\n' > "$tmp/bin/quota"
echo more >> "$repo/f"; git -C "$repo" commit -qam more
rc=0; out=$(cd "$repo" && "$script" --brief "$tmp/brief" --base main --full 2>&1) || rc=$?
[ "$rc" = 5 ] && [[ $out == *'providerInstanceId: "codex"'* ]] || fail "a full GLM week still picked GLM: $out"

# --headless runs the CLI even in T3.
rc=0; out=$(cd "$repo" && "$script" --brief "$tmp/brief" --base main --full --headless 2>&1) || rc=$?
[ -e "$tmp/cli-ran" ] || fail "--headless did not run a reviewer CLI: $out"

echo "cross-review T3 tests passed"
