#!/usr/bin/env bash
# git-as-owner.sh: a SessionStart hook that makes the session's commits the
# owner's, with no AI attribution. Run from a repo's .claude/settings.json
# (docs/install.md, "Commits carry the owner's name").
#
# 1. A clone whose git identity is Claude's (a cloud session's default)
#    commits as the owner. GitHub's squash merge adds "Co-authored-by:" for
#    every other commit author in a PR, so one Claude-authored branch commit
#    puts Claude on main even when every message is clean.
# 2. A commit-msg hook drops the trailers and footer the cloud harness asks
#    agents to add: Co-authored-by naming Claude or Anthropic, Claude-Session,
#    and "Generated with Claude Code". Human co-authors stay.
#
# Leaves alone a person's own identity and a commit-msg hook it didn't write.
set -euo pipefail

owner_name="Tom Vaucourt"
owner_email="34662901+T0mSIlver@users.noreply.github.com"
marker="# installed by git-as-owner.sh (T0mSIlver/skills)"

cd "${CLAUDE_PROJECT_DIR:-.}"
git rev-parse --git-dir > /dev/null 2>&1 || exit 0

case "$(git config user.email || true)" in
  *@anthropic.com | "")
    git config --local user.name "$owner_name"
    git config --local user.email "$owner_email"
    ;;
esac

hooks=$(git rev-parse --git-path hooks)
hook="$hooks/commit-msg"
if [ -e "$hook" ] && ! grep -qxF "$marker" "$hook"; then
  echo "git-as-owner: $hook exists and isn't mine; AI trailers won't be stripped" >&2
  exit 0
fi
mkdir -p "$hooks"
cat > "$hook" << EOF
#!/bin/sh
$marker
# Drops AI attribution lines from the message, then trailing blank lines.
msg="\$1"
grep -viE '^[[:space:]]*(co-authored-by:.*(claude|anthropic)|claude-session:)|generated with \\[?claude code' "\$msg" > "\$msg.git-as-owner" || true
git stripspace < "\$msg.git-as-owner" > "\$msg"
rm -f "\$msg.git-as-owner"
EOF
chmod +x "$hook"
