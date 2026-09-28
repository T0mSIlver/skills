# shellcheck shell=bash
# Sourced by the orch-* scripts. Loads the repo's scheduler config.
# Config: $ORCH_CONFIG, else ~/.config/orchestrate/<repo-name>.env for the repo
# of the current directory. See reference/repo-config.md for every variable.
set -u
if [ -z "${ORCH_CONFIG:-}" ]; then
  url=$(git remote get-url origin 2>/dev/null) || { echo "orch: run from a checkout of the repo, or set ORCH_CONFIG" >&2; exit 1; }
  name=$(basename "${url%.git}")
  ORCH_CONFIG="$HOME/.config/orchestrate/$name.env"
fi
[ -f "$ORCH_CONFIG" ] || { echo "orch: no config at $ORCH_CONFIG (see reference/repo-config.md)" >&2; exit 1; }
# shellcheck disable=SC1090
. "$ORCH_CONFIG"
: "${REPO:?}" "${BASE:=main}" "${GATE_CHECKS:?}" "${MUST_RUN_CHECKS:=}" "${COMBO_CHECKS:?}"
: "${CI_WORKFLOW_NAME:=CI}" "${CODE_PATHS:=.}" "${WAITS_PREFIX:=waits:}" "${STACK_LABEL:=waits:stack}"
: "${MERGE_METHOD:=squash}" "${LAG_MINUTES:=30}" "${POLL_SECONDS:=180}"
: "${OPTIONAL_CHECKS:=}" "${LANE_STEPS:=}" "${WAIVER_PATTERN:=\[skip-[a-z-]*: [^]]*\]}"
: "${BOARD_OWNER:=}" "${BOARD_NUMBER:=}" "${BOARD_ID:=}" "${BOARD_STATUS_FIELD:=}" "${BOARD_REVIEW_OPTION:=}"

# checks_of <sha> <space-separated names>: "name=conclusion ..." for the latest run of each
# (highest id: a queued run has no start time yet, and must win over an older success).
checks_of() {
  local re; re="^($(echo $2 | tr " " "|"))$"
  gh api "repos/$REPO/commits/$1/check-runs?per_page=100" --jq "[.check_runs[]|select(.name|test(\"$re\"))|{n:.name,c:(.conclusion // .status),i:.id}]|group_by(.n)|map(max_by(.i))|map(\"\(.n)=\(.c)\")|join(\" \")"
}
